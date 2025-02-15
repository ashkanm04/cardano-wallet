{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

-- |
-- Copyright: © 2022 IOHK
-- License: Apache-2.0
--
-- The 'Block' type represents blocks as they are read from the mainnet ledger.
-- It is compatible with the era-specific types from @cardano-ledger@.
module Cardano.Wallet.Read.Block
    ( ConsensusBlock
    , Block (..)
    , fromConsensusBlock
    , toConsensusBlock
    ) where

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
import Cardano.Ledger.Api
    ( StandardCrypto
    )
import Cardano.Wallet.Read.Eras
    ( EraFun (..)
    , EraValue
    , K (..)
    , allegra
    , alonzo
    , babbage
    , byron
    , conway
    , inject
    , mary
    , shelley
    )
import Ouroboros.Consensus.Protocol.Praos
    ( Praos
    )
import Ouroboros.Consensus.Protocol.TPraos
    ( TPraos
    )

import qualified Ouroboros.Consensus.Byron.Ledger as O
import qualified Ouroboros.Consensus.Cardano.Block as O
import qualified Ouroboros.Consensus.Shelley.Ledger as O

-- | Type synonym for 'CardanoBlock' with cryptography as used on mainnet.
type ConsensusBlock = O.CardanoBlock O.StandardCrypto

-- Family of era-specific block types
type family BlockT era where
    BlockT ByronEra = O.ByronBlock
    BlockT ShelleyEra =
        O.ShelleyBlock (TPraos StandardCrypto) (O.ShelleyEra StandardCrypto)
    BlockT AllegraEra =
        O.ShelleyBlock (TPraos StandardCrypto) (O.AllegraEra StandardCrypto)
    BlockT MaryEra =
        O.ShelleyBlock (TPraos StandardCrypto) (O.MaryEra StandardCrypto)
    BlockT AlonzoEra =
        O.ShelleyBlock (TPraos StandardCrypto) (O.AlonzoEra StandardCrypto)
    BlockT BabbageEra =
        O.ShelleyBlock (Praos StandardCrypto) (O.BabbageEra StandardCrypto)
    BlockT ConwayEra =
        O.ShelleyBlock (Praos StandardCrypto) (O.ConwayEra StandardCrypto)

newtype Block era = Block {unBlock :: BlockT era}

deriving instance Show (BlockT era) => Show (Block era)
deriving instance Eq (BlockT era) => Eq (Block era)

-- | Convert block as received from cardano-node
-- via Haskell library of mini-protocol.
fromConsensusBlock :: ConsensusBlock -> EraValue Block
fromConsensusBlock = \case
    O.BlockByron b -> inject byron $ Block b
    O.BlockShelley block -> inject shelley $ Block block
    O.BlockAllegra block -> inject allegra $ Block block
    O.BlockMary block -> inject mary $ Block block
    O.BlockAlonzo block -> inject alonzo $ Block block
    O.BlockBabbage block -> inject babbage $ Block block
    O.BlockConway block -> inject conway $ Block block

toConsensusBlock :: EraFun Block (K ConsensusBlock)
toConsensusBlock =
    EraFun
        { byronFun = K . O.BlockByron . unBlock
        , shelleyFun = K . O.BlockShelley . unBlock
        , allegraFun = K . O.BlockAllegra . unBlock
        , maryFun = K . O.BlockMary . unBlock
        , alonzoFun = K . O.BlockAlonzo . unBlock
        , babbageFun = K . O.BlockBabbage . unBlock
        , conwayFun = K . O.BlockConway . unBlock
        }
