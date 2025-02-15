{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE EmptyCase #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilyDependencies #-}
{-# LANGUAGE UndecidableInstances #-}

-- |
-- Copyright: © 2022 IOHK
-- License: Apache-2.0
--
-- Module containing primitive types and functionality appropriate for
-- constructing transactions.
--
-- Indented as a replacement to 'cardano-api' closer
-- to the ledger types, and only caring about the two latest eras (Cf.
-- 'RecentEra'). Intended to be used by things like balanceTx, constructTx and
-- wallet migration.
module Internal.Cardano.Write.Tx
    (
    -- * Eras
      BabbageEra
    , ConwayEra

    -- ** RecentEra
    , RecentEra (..)
    , IsRecentEra (..)
    , CardanoApiEra
    , toRecentEra
    , fromRecentEra
    , MaybeInRecentEra (..)
    , toRecentEraGADT
    , LatestLedgerEra
    , RecentEraConstraints

    -- ** Key witness counts
    , KeyWitnessCount (..)

    -- ** Helpers for cardano-api compatibility
    , cardanoEra
    , shelleyBasedEra
    , CardanoApi.ShelleyLedgerEra
    , cardanoEraFromRecentEra
    , shelleyBasedEraFromRecentEra
    , fromCardanoApiTx
    , toCardanoApiUTxO
    , fromCardanoApiUTxO
    , toCardanoApiLovelace
    , toCardanoApiTx

    -- ** Existential wrapper
    , AnyRecentEra (..)
    , toAnyCardanoEra
    , fromAnyCardanoEra

    -- ** Misc
    , StandardCrypto
    , StandardBabbage
    , StandardConway

    -- * PParams
    , PParams
    , PParamsInAnyRecentEra (..)
    , FeePerByte (..)
    , getFeePerByte
    , feeOfBytes
    , maxScriptExecutionCost
    , stakeKeyDeposit
    , ProtVer (..)
    , Version

    -- * Tx
    , Core.Tx
    , Core.TxBody
    , emptyTx
    , serializeTx

    -- * TxId
    , Ledger.TxId

    -- * TxOut
    , Core.TxOut
    , BabbageTxOut (..)
    , TxOutInBabbage
    , TxOutInRecentEra (..)
    , unwrapTxOutInRecentEra

    , computeMinimumCoinForTxOut
    , isBelowMinimumCoinForTxOut

    -- ** Address
    , Address
    , unsafeAddressFromBytes

    -- ** Value
    , Value
    , modifyCoin
    , coin
    , Coin (..)

    -- ** Datum
    , Datum (..)

    -- *** Binary Data
    , BinaryData

    -- *** Datum Hash
    , DatumHash
    , datumHashFromBytes
    , datumHashToBytes

    -- ** Rewards
    , RewardAccount

    -- ** Script
    , Script
    , Alonzo.isPlutusScript

    -- * TxIn
    , TxIn
    , unsafeMkTxIn

    -- * UTxO
    , Shelley.UTxO (..)
    , utxoFromTxOutsInRecentEra
    , utxoFromTxOuts

    -- * Policy and asset identifiers
    , PolicyId
    , AssetName

    -- * Balancing
    , evaluateMinimumFee
    , evaluateTransactionBalance
    )
    where

import Prelude

import Cardano.Crypto.Hash
    ( Hash (UnsafeHash)
    )
import Cardano.Ledger.Allegra.Scripts
    ( translateTimelock
    )
import Cardano.Ledger.Alonzo.Scripts
    ( AlonzoScript (..)
    )
import Cardano.Ledger.Alonzo.Scripts.Data
    ( BinaryData
    , Datum (..)
    )
import Cardano.Ledger.Alonzo.TxInfo
    ( ExtendedUTxO
    )
import Cardano.Ledger.Alonzo.TxWits
    ( AlonzoTxWits
    )
import Cardano.Ledger.Alonzo.UTxO
    ( AlonzoScriptsNeeded
    )
import Cardano.Ledger.Api
    ( coinTxOutL
    )
import Cardano.Ledger.Api.UTxO
    ( EraUTxO (ScriptsNeeded)
    )
import Cardano.Ledger.Babbage.TxBody
    ( BabbageTxOut (..)
    )
import Cardano.Ledger.BaseTypes
    ( ProtVer (..)
    , Version
    , maybeToStrictMaybe
    )
import Cardano.Ledger.Coin
    ( Coin (..)
    )
import Cardano.Ledger.Crypto
    ( StandardCrypto
    )
import Cardano.Ledger.Mary
    ( MaryValue
    )
import Cardano.Ledger.Mary.Value
    ( AssetName
    , PolicyID
    )
import Cardano.Ledger.SafeHash
    ( SafeHash
    , extractHash
    , unsafeMakeSafeHash
    )
import Cardano.Ledger.Val
    ( coin
    , modifyCoin
    )
import Control.Arrow
    ( second
    , (>>>)
    )
import Data.ByteString
    ( ByteString
    )
import Data.ByteString.Short
    ( toShort
    )
import Data.Coerce
    ( coerce
    )
import Data.Generics.Internal.VL.Lens
    ( over
    , (^.)
    )
import Data.Generics.Labels
    ()
import Data.IntCast
    ( intCast
    , intCastMaybe
    )
import Data.Kind
    ( Type
    )
import Data.Maybe
    ( fromMaybe
    , isJust
    )
import Data.Type.Equality
    ( (:~:) (Refl)
    , TestEquality (testEquality)
    )
import Data.Typeable
    ( Typeable
    )
import GHC.Stack
    ( HasCallStack
    )
import Numeric.Natural
    ( Natural
    )
import Ouroboros.Consensus.Shelley.Eras
    ( StandardBabbage
    , StandardConway
    )

import qualified Cardano.Api as CardanoApi
import qualified Cardano.Api.Byron as CardanoApi
import qualified Cardano.Api.Shelley as CardanoApi
import qualified Cardano.Crypto.Hash.Class as Crypto
import qualified Cardano.Ledger.Address as Ledger
import qualified Cardano.Ledger.Alonzo.Core as Alonzo
import qualified Cardano.Ledger.Alonzo.Scripts as Alonzo
import qualified Cardano.Ledger.Alonzo.Scripts.Data as Alonzo
import qualified Cardano.Ledger.Api as Ledger
import qualified Cardano.Ledger.Babbage as Babbage
import qualified Cardano.Ledger.Babbage.Tx as Babbage
import qualified Cardano.Ledger.Babbage.TxBody as Babbage
import qualified Cardano.Ledger.Core as Core
import qualified Cardano.Ledger.Credential as Core
import qualified Cardano.Ledger.Keys as Ledger
import qualified Cardano.Ledger.Shelley.API.Wallet as Shelley
import qualified Cardano.Ledger.Shelley.UTxO as Shelley
import qualified Cardano.Ledger.TxIn as Ledger
import qualified Cardano.Wallet.Primitive.Ledger.Convert as Convert
import qualified Cardano.Wallet.Primitive.Types.Tx.Constraints as W
    ( txOutMaxCoin
    )
import qualified Data.Map as Map

--------------------------------------------------------------------------------
-- Eras
--------------------------------------------------------------------------------

type BabbageEra = Ledger.BabbageEra StandardCrypto
type ConwayEra = Ledger.ConwayEra StandardCrypto

type LatestLedgerEra = StandardConway

--------------------------------------------------------------------------------
-- RecentEra
--------------------------------------------------------------------------------

-- | 'RecentEra' respresents the eras we care about constructing transactions
-- for.
--
-- To have the same software constructing transactions just before and just
-- after a hard-fork, we need to, at that time, support the two latest eras. We
-- could get away with just supporting one era at other times, but for
-- simplicity we stick with always supporting the two latest eras for now.
--
-- NOTE: We /could/ let 'era' refer to eras from the ledger rather than from
-- cardano-api.
data RecentEra era where
    RecentEraBabbage :: RecentEra BabbageEra
    RecentEraConway :: RecentEra ConwayEra

deriving instance Eq (RecentEra era)
deriving instance Show (RecentEra era)

instance TestEquality RecentEra where
    testEquality RecentEraBabbage RecentEraBabbage = Just Refl
    testEquality RecentEraConway RecentEraConway = Just Refl
    testEquality RecentEraBabbage RecentEraConway = Nothing
    testEquality RecentEraConway RecentEraBabbage = Nothing

class
    ( CardanoApi.IsShelleyBasedEra (CardanoApiEra era)
    , CardanoApi.ShelleyLedgerEra (CardanoApiEra era) ~ era
    , Typeable era
    , RecentEraConstraints era
    ) => IsRecentEra era where
    recentEra :: RecentEra era

type family CardanoApiEra era = cardanoApiEra | cardanoApiEra -> era
type instance CardanoApiEra BabbageEra = CardanoApi.BabbageEra
type instance CardanoApiEra ConwayEra = CardanoApi.ConwayEra

-- | Convenient constraints. Constraints may be dropped as we move to new eras.
--
-- Adding too many constraints shouldn't be a concern as the point of
-- 'RecentEra' is to work with a small closed set of eras, anyway.
type RecentEraConstraints era =
    ( Core.Era era
    , Core.EraTx era
    , Core.EraCrypto era ~ StandardCrypto
    , Core.Script era ~ AlonzoScript era
    , Core.Tx era ~ Babbage.AlonzoTx era
    , Core.Value era ~ Value
    , Core.TxWits era ~ AlonzoTxWits era
    , ExtendedUTxO era
    , Alonzo.AlonzoEraPParams era
    , Ledger.AlonzoEraTx era
    , ScriptsNeeded era ~ AlonzoScriptsNeeded era
    , Eq (TxOut era)
    , Ledger.Crypto (Core.EraCrypto era)
    , Show (TxOut era)
    , Show (Core.Tx era)
    , Eq (Core.Tx era)
    , Babbage.BabbageEraTxBody era
    , Shelley.EraUTxO era
    , Show (TxOut era)
    , Eq (TxOut era)
    , Show (PParams era)
    )

-- | Returns a proof that the given era is a recent era.
--
-- Otherwise, returns @Nothing@.
toRecentEra
    :: CardanoApi.CardanoEra era
    -> Maybe (RecentEra (CardanoApi.ShelleyLedgerEra era))
toRecentEra = \case
    CardanoApi.ConwayEra  -> Just RecentEraConway
    CardanoApi.BabbageEra -> Just RecentEraBabbage
    CardanoApi.AlonzoEra  -> Nothing
    CardanoApi.MaryEra    -> Nothing
    CardanoApi.AllegraEra -> Nothing
    CardanoApi.ShelleyEra -> Nothing
    CardanoApi.ByronEra   -> Nothing

fromRecentEra :: RecentEra era -> CardanoApi.CardanoEra (CardanoApiEra era)
fromRecentEra = \case
    RecentEraConway -> CardanoApi.ConwayEra
    RecentEraBabbage -> CardanoApi.BabbageEra

instance IsRecentEra BabbageEra where
    recentEra = RecentEraBabbage

instance IsRecentEra ConwayEra where
    recentEra = RecentEraConway

cardanoEraFromRecentEra
    :: RecentEra era
    -> CardanoApi.CardanoEra (CardanoApiEra era)
cardanoEraFromRecentEra =
    CardanoApi.shelleyBasedToCardanoEra
    . shelleyBasedEraFromRecentEra

shelleyBasedEraFromRecentEra
    :: RecentEra era
    -> CardanoApi.ShelleyBasedEra (CardanoApiEra era)
shelleyBasedEraFromRecentEra = \case
    RecentEraConway -> CardanoApi.ShelleyBasedEraConway
    RecentEraBabbage -> CardanoApi.ShelleyBasedEraBabbage

-- Similar to 'CardanoApi.cardanoEra', but with an 'IsRecentEra era' constraint
-- instead of 'CardanoApi.IsCardanoEra'.
cardanoEra
    :: forall era. IsRecentEra era
    => CardanoApi.CardanoEra (CardanoApiEra era)
cardanoEra = cardanoEraFromRecentEra $ recentEra @era

-- | For convenience working with 'IsRecentEra'.
--
-- Similar to 'CardanoApi.shelleyBasedEra, but with a 'IsRecentEra era'
-- constraint instead of 'CardanoApi.IsShelleyBasedEra'.
shelleyBasedEra
    :: forall era. IsRecentEra era
    => CardanoApi.ShelleyBasedEra (CardanoApiEra era)
shelleyBasedEra = shelleyBasedEraFromRecentEra $ recentEra @era

data MaybeInRecentEra (thing :: Type -> Type)
    = InNonRecentEraByron
    | InNonRecentEraShelley
    | InNonRecentEraAllegra
    | InNonRecentEraMary
    | InNonRecentEraAlonzo
    | InRecentEraBabbage (thing BabbageEra)
    | InRecentEraConway (thing ConwayEra)

deriving instance (Eq (a BabbageEra), (Eq (a ConwayEra)))
    => Eq (MaybeInRecentEra a)
deriving instance (Show (a BabbageEra), (Show (a ConwayEra)))
    => Show (MaybeInRecentEra a)

-- | An existential type like 'AnyCardanoEra', but for 'RecentEra'.
data AnyRecentEra where
    AnyRecentEra
        :: IsRecentEra era -- Provide class constraint
        => RecentEra era   -- and explicit value.
        -> AnyRecentEra    -- and that's it.

instance Enum AnyRecentEra where
    -- NOTE: We're not starting at 0! 0 would be Byron, which is not a recent
    -- era.
    fromEnum = fromEnum . toAnyCardanoEra
    toEnum n = fromMaybe err . fromAnyCardanoEra $ toEnum n
      where
        err = error $ unwords
            [ "AnyRecentEra.toEnum:", show n
            , "doesn't correspond to a recent era."
            ]

instance Bounded AnyRecentEra where
    minBound = AnyRecentEra RecentEraBabbage
    maxBound = AnyRecentEra RecentEraConway

instance Show AnyRecentEra where
    show (AnyRecentEra era) = "AnyRecentEra " <> show era

instance Eq AnyRecentEra where
    AnyRecentEra e1 == AnyRecentEra e2 =
        isJust $ testEquality e1 e2

toAnyCardanoEra :: AnyRecentEra -> CardanoApi.AnyCardanoEra
toAnyCardanoEra (AnyRecentEra era) =
    CardanoApi.AnyCardanoEra (fromRecentEra era)

fromAnyCardanoEra
    :: CardanoApi.AnyCardanoEra
    -> Maybe AnyRecentEra
fromAnyCardanoEra = \case
    CardanoApi.AnyCardanoEra CardanoApi.ByronEra ->
        Nothing
    CardanoApi.AnyCardanoEra CardanoApi.ShelleyEra ->
        Nothing
    CardanoApi.AnyCardanoEra CardanoApi.AllegraEra ->
        Nothing
    CardanoApi.AnyCardanoEra CardanoApi.MaryEra ->
        Nothing
    CardanoApi.AnyCardanoEra CardanoApi.AlonzoEra ->
        Nothing
    CardanoApi.AnyCardanoEra CardanoApi.BabbageEra ->
        Just $ AnyRecentEra RecentEraBabbage
    CardanoApi.AnyCardanoEra CardanoApi.ConwayEra ->
        Just $ AnyRecentEra RecentEraConway

--------------------------------------------------------------------------------
-- Key witness counts
--------------------------------------------------------------------------------

data KeyWitnessCount = KeyWitnessCount
    { nKeyWits :: !Word
    -- ^ "Normal" verification key witnesses introduced with the Shelley era.

    , nBootstrapWits :: !Word
    -- ^ Bootstrap key witnesses, a.k.a Byron witnesses.
    } deriving (Eq, Show)

instance Semigroup KeyWitnessCount where
    (KeyWitnessCount s1 b1) <> (KeyWitnessCount s2 b2)
        = KeyWitnessCount (s1 + s2) (b1 + b2)

instance Monoid KeyWitnessCount where
    mempty = KeyWitnessCount 0 0

--------------------------------------------------------------------------------
-- TxIn
--------------------------------------------------------------------------------

type TxIn = Ledger.TxIn StandardCrypto

-- | Useful for testing
unsafeMkTxIn :: ByteString -> Word -> TxIn
unsafeMkTxIn hash ix = Ledger.mkTxInPartial
    (toTxId hash)
    (fromIntegral ix)
  where
    toTxId :: ByteString -> Ledger.TxId StandardCrypto
    toTxId h =
        (Ledger.TxId (unsafeMakeSafeHash $ UnsafeHash $ toShort h))

--------------------------------------------------------------------------------
-- TxOut
--------------------------------------------------------------------------------

type TxOut era = Core.TxOut era

type TxOutInBabbage = Babbage.BabbageTxOut (Babbage.BabbageEra StandardCrypto)

type Address = Ledger.Addr StandardCrypto

type RewardAccount = Ledger.RewardAcnt StandardCrypto
type Script = AlonzoScript
type Value = MaryValue StandardCrypto

unsafeAddressFromBytes :: ByteString -> Address
unsafeAddressFromBytes bytes = case Ledger.deserialiseAddr bytes of
    Just addr -> addr
    Nothing -> error "unsafeAddressFromBytes: failed to deserialise"

type DatumHash = Alonzo.DataHash StandardCrypto

datumHashFromBytes :: ByteString -> Maybe DatumHash
datumHashFromBytes = fmap unsafeMakeSafeHash <$> Crypto.hashFromBytes

datumHashToBytes :: SafeHash crypto a -> ByteString
datumHashToBytes = Crypto.hashToBytes . extractHash

-- | Type representing a TxOut in the latest or previous era.
--
-- The underlying representation is isomorphic to 'TxOut LatestLedgerEra'.
--
-- Can be unwrapped using 'unwrapTxOutInRecentEra' or
-- 'utxoFromTxOutsInRecentEra'.
--
-- Implementation assumes @TxOut latestEra ⊇ TxOut prevEra@ in the sense that
-- the latest era has not removed information from the @TxOut@. This allows
-- e.g. @ToJSON@ / @FromJSON@ instances to be written for two eras using only
-- one implementation.
data TxOutInRecentEra =
    TxOutInRecentEra
        Address
        Value
        (Datum LatestLedgerEra)
        (Maybe (AlonzoScript LatestLedgerEra))
        -- Same contents as 'TxOut LatestLedgerEra'.

unwrapTxOutInRecentEra
    :: RecentEra era
    -> TxOutInRecentEra
    -> TxOut era
unwrapTxOutInRecentEra era recentEraTxOut = case era of
    RecentEraConway -> recentEraToConwayTxOut recentEraTxOut
    RecentEraBabbage -> recentEraToBabbageTxOut recentEraTxOut

recentEraToConwayTxOut
    :: TxOutInRecentEra
    -> Babbage.BabbageTxOut LatestLedgerEra
recentEraToConwayTxOut (TxOutInRecentEra addr val datum mscript) =
    Babbage.BabbageTxOut addr val datum (maybeToStrictMaybe mscript)

recentEraToBabbageTxOut
    :: TxOutInRecentEra
    -> Babbage.BabbageTxOut (Babbage.BabbageEra StandardCrypto)
recentEraToBabbageTxOut (TxOutInRecentEra addr val datum mscript) =
    Babbage.BabbageTxOut addr val
        (castDatum datum)
        (maybeToStrictMaybe (castScript <$> mscript))
  where
    castDatum = \case
        Alonzo.NoDatum ->
            Alonzo.NoDatum
        Alonzo.DatumHash h ->
            Alonzo.DatumHash h
        Alonzo.Datum binaryData ->
            Alonzo.Datum (coerce binaryData)
    castScript :: AlonzoScript StandardConway -> AlonzoScript StandardBabbage
    castScript = \case
        Alonzo.TimelockScript timelockEra ->
            Alonzo.TimelockScript (translateTimelock timelockEra)
        Alonzo.PlutusScript l bs ->
            Alonzo.PlutusScript l bs

--
-- MinimumUTxO
--

-- | Compute the minimum ada quantity required for a given 'TxOut'.
--
-- Unlike @Ledger.evaluateMinLovelaceOutput@, this function may return an
-- overestimation for the sake of satisfying the property:
--
-- @
--     forall out.
--     let
--         c = computeMinimumCoinForUTxO out
--     in
--         forall c' >= c.
--         not $ isBelowMinimumCoinForTxOut modifyTxOutCoin (const c') out
-- @
--
-- This makes it easy for callers to create outputs with near-minimum ada
-- quantities regardless of the fact that modifying the ada 'Coin' value may
-- itself change the size and min-ada requirement.
computeMinimumCoinForTxOut
    :: forall era. IsRecentEra era
    => PParams era
    -> TxOut era
    -> Coin
computeMinimumCoinForTxOut pp out =
    Core.getMinCoinTxOut pp (withMaxLengthSerializedCoin out)
  where
    withMaxLengthSerializedCoin
        :: TxOut era
        -> TxOut era
    withMaxLengthSerializedCoin =
        over coinTxOutL (const $ Convert.toLedger W.txOutMaxCoin)

isBelowMinimumCoinForTxOut
    :: forall era. IsRecentEra era
    => PParams era
    -> TxOut era
    -> Bool
isBelowMinimumCoinForTxOut pp out =
    actualCoin < requiredMin
  where
    -- IMPORTANT to use the exact minimum from the ledger function, and not our
    -- overestimating 'computeMinimumCoinForTxOut'.
    requiredMin = Core.getMinCoinTxOut pp out
    actualCoin = out ^. coinTxOutL

--------------------------------------------------------------------------------
-- UTxO
--------------------------------------------------------------------------------

-- | Construct a 'UTxO era' using 'TxIn's and 'TxOut's in said era.
utxoFromTxOuts
    :: IsRecentEra era
    => [(TxIn, Core.TxOut era)]
    -> Shelley.UTxO era
utxoFromTxOuts = Shelley.UTxO . Map.fromList

-- | Construct a 'UTxO era' using 'TxOutInRecentEra'.
--
-- Used to have a possibility for failure when we supported Alonzo and Babbage,
-- and could possibly become failable again with future eras.
utxoFromTxOutsInRecentEra
    :: forall era. IsRecentEra era
    => RecentEra era
    -> [(TxIn, TxOutInRecentEra)]
    -> Shelley.UTxO era
utxoFromTxOutsInRecentEra era =
    Shelley.UTxO . Map.fromList . map (second (unwrapTxOutInRecentEra era))

--------------------------------------------------------------------------------
-- Tx
--------------------------------------------------------------------------------

serializeTx
    :: forall era. IsRecentEra era
    => Core.Tx era
    -> ByteString
serializeTx tx = CardanoApi.serialiseToCBOR $ toCardanoApiTx @era tx

emptyTx
    :: IsRecentEra era
    => RecentEra era
    -> Core.Tx era
emptyTx _era = Core.mkBasicTx Core.mkBasicTxBody

--------------------------------------------------------------------------------
-- Compatibility
--------------------------------------------------------------------------------

fromCardanoApiTx
    :: forall era. IsRecentEra era
    => CardanoApi.Tx (CardanoApiEra era)
    -> Core.Tx era
fromCardanoApiTx = \case
    CardanoApi.ShelleyTx _era tx ->
        tx
    CardanoApi.ByronTx {} ->
        case (recentEra @era) of
            {}

toCardanoApiTx
    :: forall era. IsRecentEra era
    => Core.Tx era
    -> CardanoApi.Tx (CardanoApiEra era)
toCardanoApiTx =
    CardanoApi.ShelleyTx (shelleyBasedEraFromRecentEra $ recentEra @era)

toCardanoApiUTxO
    :: forall era. IsRecentEra era
    => Shelley.UTxO era
    -> CardanoApi.UTxO (CardanoApiEra era)
toCardanoApiUTxO =
    CardanoApi.UTxO
    . Map.mapKeys CardanoApi.fromShelleyTxIn
    . Map.map (CardanoApi.fromShelleyTxOut (shelleyBasedEra @era))
    . unUTxO
  where
    unUTxO (Shelley.UTxO m) = m

fromCardanoApiUTxO
    :: forall era. IsRecentEra era
    => CardanoApi.UTxO (CardanoApiEra era)
    -> Shelley.UTxO era
fromCardanoApiUTxO =
    Shelley.UTxO
    . Map.mapKeys CardanoApi.toShelleyTxIn
    . Map.map
        (CardanoApi.toShelleyTxOut (shelleyBasedEra @era))
    . CardanoApi.unUTxO

toCardanoApiLovelace :: Coin -> CardanoApi.Lovelace
toCardanoApiLovelace = CardanoApi.fromShelleyLovelace

--------------------------------------------------------------------------------
-- PParams
--------------------------------------------------------------------------------

type PParams = Core.PParams

data PParamsInAnyRecentEra where
    PParamsInAnyRecentEra
        :: IsRecentEra era
        => RecentEra era
        -> PParams era
        -> PParamsInAnyRecentEra

toRecentEraGADT
    :: MaybeInRecentEra PParams
    -> Either CardanoApi.AnyCardanoEra PParamsInAnyRecentEra
toRecentEraGADT = \case
    InNonRecentEraByron ->
        Left $ CardanoApi.AnyCardanoEra CardanoApi.ByronEra
    InNonRecentEraShelley ->
        Left $ CardanoApi.AnyCardanoEra CardanoApi.ShelleyEra
    InNonRecentEraAllegra ->
        Left $ CardanoApi.AnyCardanoEra CardanoApi.AllegraEra
    InNonRecentEraMary ->
        Left $ CardanoApi.AnyCardanoEra CardanoApi.MaryEra
    InNonRecentEraAlonzo ->
        Left $ CardanoApi.AnyCardanoEra CardanoApi.AlonzoEra
    InRecentEraBabbage a ->
        Right $ PParamsInAnyRecentEra recentEra a
    InRecentEraConway a ->
        Right $ PParamsInAnyRecentEra recentEra a

-- | The 'minfeeA' protocol parameter in unit @lovelace/byte@.
newtype FeePerByte = FeePerByte Natural
    deriving (Show, Eq)

getFeePerByte
    :: forall era. (HasCallStack, IsRecentEra era)
    => PParams era
    -> FeePerByte
getFeePerByte pp =
    unsafeCoinToFee $
        case recentEra @era of
            RecentEraConway -> pp ^. Core.ppMinFeeAL
            RecentEraBabbage -> pp ^. Core.ppMinFeeAL
  where
    unsafeCoinToFee :: Coin -> FeePerByte
    unsafeCoinToFee = unCoin >>> intCastMaybe >>> \case
        Just fee -> FeePerByte fee
        Nothing -> error "Impossible: min fee protocol parameter is negative"

feeOfBytes :: FeePerByte -> Natural -> Coin
feeOfBytes (FeePerByte perByte) bytes = Coin $ intCast $ perByte * bytes

type ExUnitPrices = Alonzo.Prices

type ExUnits = Alonzo.ExUnits

txscriptfee :: ExUnitPrices -> ExUnits -> Coin
txscriptfee = Alonzo.txscriptfee

maxScriptExecutionCost :: IsRecentEra era => PParams era -> Coin
maxScriptExecutionCost pp =
    txscriptfee (pp ^. Alonzo.ppPricesL) (pp ^. Alonzo.ppMaxTxExUnitsL)

stakeKeyDeposit :: IsRecentEra era => PParams era -> Coin
stakeKeyDeposit pp = pp ^. Core.ppKeyDepositL

--------------------------------------------------------------------------------
-- Balancing
--------------------------------------------------------------------------------

-- | Computes the minimal fee amount necessary to pay for a given transaction.
--
evaluateMinimumFee
    :: IsRecentEra era
    => PParams era
    -> Core.Tx era
    -> KeyWitnessCount
    -> Coin
evaluateMinimumFee pp tx kwc =
    mainFee <> bootWitnessFee
  where
    KeyWitnessCount {nKeyWits, nBootstrapWits} = kwc

    mainFee :: Coin
    mainFee = Shelley.evaluateTransactionFee pp tx nKeyWits

    FeePerByte feePerByte = getFeePerByte pp

    bootWitnessFee :: Coin
    bootWitnessFee = Coin $ intCast $ feePerByte * byteCount
      where
        byteCount :: Natural
        byteCount = sizeOf_BootstrapWitnesses $ intCast nBootstrapWits

        -- Matching implementation in "Cardano.Wallet.Shelley.Transaction".
        -- Equivalence is tested in property.
        sizeOf_BootstrapWitnesses :: Natural -> Natural
        sizeOf_BootstrapWitnesses 0 = 0
        sizeOf_BootstrapWitnesses n = 4 + 180 * n

-- | Evaluate the /balance/ of a transaction using the ledger.
--
-- The balance is defined as:
-- @
-- (value consumed by transaction) - (value produced by transaction)
-- @
--
-- For a transaction to be valid, it must have a balance of __zero__.
--
-- Note that the fee field of the transaction affects the balance, and
-- is not automatically the minimum fee.
--
evaluateTransactionBalance
    :: forall era. IsRecentEra era
    => PParams era
    -> Shelley.UTxO era
    -> Core.TxBody era
    -> Core.Value era
evaluateTransactionBalance pp utxo =
    let -- Looks up the current deposit amount for a registered stake credential
        -- delegation.
        --
        -- This function must produce a valid answer for all stake credentials
        -- present in any of the 'DeRegKey' delegation certificates in the
        -- supplied 'TxBody'. In other words, there is no requirement to know
        -- about all of the delegation certificates in the ledger state,
        -- just those this transaction cares about.
        lookupRefund :: Core.StakeCredential StandardCrypto -> Maybe Coin
        lookupRefund _stakeCred = Just $ pp ^. Core.ppKeyDepositL

        -- Checks whether a pool with a supplied 'PoolStakeId' is already
        -- registered.
        --
        -- There is no requirement to answer this question for all stake pool
        -- credentials, just those that have their registration certificates
        -- included in the supplied 'TxBody'.
        isRegPoolId :: Ledger.KeyHash 'Ledger.StakePool StandardCrypto -> Bool
        isRegPoolId _keyHash = True

    in Ledger.evalBalanceTxBody pp lookupRefund isRegPoolId utxo

--------------------------------------------------------------------------------
-- Policy and asset identifiers
--------------------------------------------------------------------------------

type PolicyId = PolicyID StandardCrypto
