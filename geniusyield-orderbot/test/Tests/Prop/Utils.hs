module Tests.Prop.Utils where

import Test.QuickCheck

import Data.Ratio

import GeniusYield.OrderBot.Types
import GeniusYield.Types
import Data.String (IsString(fromString))


-- | Generator for the strategy tests. Using a hardcoded assetPair of GOLD <> ADA
genOrderInfos :: Gen (OrderAssetPair, [OrderInfo 'BuyOrder], [OrderInfo 'SellOrder])
genOrderInfos = do
    buyOrders <- listOf1 $ genBuyOrder oap
    sellOrders <- listOf1 $ genSellOrder oap
    return (oap, buyOrders, sellOrders)
  where
    goldPolicyId = "ff80aaaf03a273b8f5c558168dc0e2377eea810badbae6eceefc14ef"
    oap = mkOrderAssetPair GYLovelace (GYToken goldPolicyId "GOLD")

-- | Generator for a GYTxOutRef with a very optimistic n
genGYTxOutRef :: Gen GYTxOutRef
genGYTxOutRef = do
    id <- vectorOf 64 genHexString
    n <- chooseInteger (0,1000)
    return $ fromString $ id ++ "#" ++ show n

-- | Hex characters used in the GYTxOutRef generator
genHexString :: Gen Char
genHexString = elements $ ['a'..'f'] ++ ['0'..'9']

-- | Generator for the Volume. With a fixed minVolume of 34%
genVolume :: Gen Volume
genVolume = do
    vh <- chooseInteger (100,100000000)
    pure $ Volume (ceiling $ (vh % 1) * (34 % 100)) (fromIntegral vh)

{- | Generator for the Volume. With a fixed minVolume of 34%.
with an specified minimum and maximum.
-}
genVolume' :: Integer -> Integer -> Gen Volume
genVolume' min max = do
    vh <- chooseInteger (ceiling $ (1 % min) * (34 % 100) , max)
    pure $ Volume (ceiling $ (vh % 1) * (34 % 100)) (fromIntegral vh)

-- | Generates a random price between 1/100 and 100
genPrice :: Gen Price
genPrice = do
    n <- chooseInteger (1,100)
    m <- chooseInteger (1,100)
    return $ Price (n % m)

-- | Generator for a buy order, using all previous generators
genBuyOrder :: OrderAssetPair -> Gen (OrderInfo 'BuyOrder)
genBuyOrder oap = OrderInfo <$> genGYTxOutRef
                            <*> pure SBuyOrder
                            <*> pure oap
                            <*> genVolume
                            <*> genPrice
                            <*> pure Nothing

-- | Generator for a sell order, using all previous generators
genSellOrder :: OrderAssetPair -> Gen (OrderInfo 'SellOrder)
genSellOrder oap = OrderInfo <$> genGYTxOutRef
                             <*> pure SSellOrder
                             <*> pure oap
                             <*> genVolume
                             <*> genPrice
                             <*> pure Nothing

{- | Shrink function for the tuples used in properties.

    Shrinks, in order:
        * Buy Orders
        * Sell Orders
-}
shrinkTuple
    :: (OrderAssetPair, [OrderInfo 'BuyOrder], [OrderInfo 'SellOrder])
    -> [(OrderAssetPair, [OrderInfo 'BuyOrder], [OrderInfo 'SellOrder])]
shrinkTuple (oap, xs, ys) =
    [ (oap, xs', ys) | xs' <- shrinkList shrinkOrderInfo xs ] ++
    [ (oap, xs, ys') | ys' <- shrinkList shrinkOrderInfo ys ]

-- | Shrinks an OrderInfo by shrinking it's volume
shrinkOrderInfo :: forall t. OrderInfo t -> [OrderInfo t]
shrinkOrderInfo order =
    [ order { volume = vol'} | vol' <- shrinkVolume (volume order) ]

-- | Shrinks a Volume by making sure the min is positive and the max is over the min
shrinkVolume :: Volume -> [Volume]
shrinkVolume v@Volume{volumeMin, volumeMax} =
    [ v { volumeMin = vl' } | vl' <- shrinkIntegral volumeMin, vl' > 0 ] ++
    [ v { volumeMax = vh' } | vh' <- shrinkIntegral volumeMax, vh' > volumeMin ]
