{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

-- |
-- Copyright: © 2020-2022 IOHK
-- License: Apache-2.0
--
-- Raw collateral output data extraction from 'Tx'
--

module Cardano.Wallet.Read.Tx.CollateralOutputs
    ( CollateralOutputsType
    , CollateralOutputs (..)
    , getEraCollateralOutputs
    )
    where

import Prelude

import Cardano.Api
    ( AllegraEra
    , AlonzoEra
    , BabbageEra
    , ByronEra
    , ConwayEra
    , MaryEra
    , ShelleyEra
    )
import Cardano.Ledger.Babbage.Collateral
    ()
import Cardano.Ledger.Babbage.Rules
    ()
import Cardano.Ledger.Babbage.Tx
    ()
import Cardano.Ledger.Babbage.TxBody
    ( BabbageTxOut (..)
    , collateralReturnTxBodyL
    )
import Cardano.Ledger.Core
    ( bodyTxL
    )
import Cardano.Ledger.Crypto
    ( StandardCrypto
    )
import Cardano.Wallet.Read.Eras
    ( EraFun (..)
    )
import Cardano.Wallet.Read.Tx
    ( Tx (..)
    )
import Cardano.Wallet.Read.Tx.Eras
    ( onTx
    )
import Control.Lens
    ( (^.)
    )
import Data.Maybe.Strict
    ( StrictMaybe
    )

import qualified Cardano.Ledger.Babbage as BA
import qualified Cardano.Ledger.Conway as Conway

type family CollateralOutputsType era where
    CollateralOutputsType ByronEra = ()
    CollateralOutputsType ShelleyEra = ()
    CollateralOutputsType AllegraEra = ()
    CollateralOutputsType MaryEra = ()
    CollateralOutputsType AlonzoEra =  ()
    CollateralOutputsType BabbageEra
        = StrictMaybe (BabbageTxOut (BA.BabbageEra StandardCrypto))
    CollateralOutputsType ConwayEra
        = StrictMaybe (BabbageTxOut (Conway.ConwayEra StandardCrypto))

newtype CollateralOutputs era = CollateralOutputs (CollateralOutputsType era)

deriving instance Show (CollateralOutputsType era)
    => Show (CollateralOutputs era)
deriving instance Eq (CollateralOutputsType era) => Eq (CollateralOutputs era)

-- | Get the 'CollateralOutputs' for a given 'Tx' in any era.
getEraCollateralOutputs :: EraFun Tx CollateralOutputs
getEraCollateralOutputs
    = EraFun
        { byronFun =  \_ -> CollateralOutputs ()
        , shelleyFun = \_ -> CollateralOutputs ()
        , allegraFun = \_ -> CollateralOutputs ()
        , maryFun = \_ -> CollateralOutputs ()
        , alonzoFun = \_ -> CollateralOutputs ()
        , babbageFun = mkCollateralOutputs
        , conwayFun = mkCollateralOutputs
        }
    where
          mkCollateralOutputs  = onTx $ \tx -> CollateralOutputs
            $ tx ^. bodyTxL . collateralReturnTxBodyL
