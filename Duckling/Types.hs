-- Copyright (c) 2016-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree.


{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoRebindableSyntax #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE NamedFieldPuns #-}

module Duckling.Types where

import Control.DeepSeq
import Data.Aeson
import Data.GADT.Compare
import Data.GADT.Show
import Data.Hashable
import Data.HashMap.Strict (HashMap)
import Data.HashSet (HashSet)
import Data.List (intersperse, sortOn)
import Data.Maybe
import Data.Text (Text, toLower, unpack)
import Data.Typeable ((:~:)(Refl), eqT, Typeable)
import GHC.Generics
import Prelude
import TextShow (TextShow(..))
import qualified Data.ByteString.Lazy as LB
import qualified Data.HashMap.Strict as HashMap
import qualified Data.Text as TT
import qualified Data.Text.Encoding as Text
import qualified Text.Regex.Base as R
import qualified Text.Regex.PCRE as PCRE
import qualified TextShow as TS

import Duckling.AmountOfMoney.Types (AmountOfMoneyData)
import Duckling.CreditCardNumber.Types (CreditCardNumberData)
import Duckling.Distance.Types (DistanceData)
import Duckling.Duration.Types (DurationData)
import Duckling.Email.Types (EmailData)
import Duckling.Locale
import Duckling.Numeral.Types (NumeralData)
import Duckling.Ordinal.Types (OrdinalData)
import Duckling.PhoneNumber.Types (PhoneNumberData)
import Duckling.Quantity.Types (QuantityData)
import Duckling.Regex.Types
import Duckling.Resolve
import Duckling.Temperature.Types (TemperatureData)
import Duckling.Time.Types (TimeData)
import Duckling.TimeGrain.Types (Grain)
import Duckling.Url.Types (UrlData)
import Duckling.Volume.Types (VolumeData)

-- -----------------------------------------------------------------
-- Token

data Token = forall a . (Resolve a, Eq a, Hashable a, Show a, NFData a) =>
  Token (Dimension a) a

deriving instance Show Token
instance Eq Token where
  Token d1 v1 == Token d2 v2 = case geq d1 d2 of
    Just Refl -> v1 == v2
    Nothing   -> False

instance Hashable Token where
  hashWithSalt s (Token d v) = hashWithSalt s (d, v)

instance NFData Token where
  rnf (Token _ v) = rnf v

-- -----------------------------------------------------------------
-- Seal

data Seal s where
  Seal :: s a -> Seal s

instance GEq s => Eq (Seal s) where
  Seal x == Seal y =
    defaultEq x y

instance GShow s => Show (Seal s) where
  showsPrec p (Seal s)
    = showParen (p > 10) (showString "Seal " . gshowsPrec 11 s)

withSeal :: Seal s -> (forall t. s t -> r) -> r
withSeal (Seal x) f = f x

-- -----------------------------------------------------------------
-- Dimension

class (Show a, Typeable a, Typeable (DimensionData  a)) =>
    CustomDimension a where
  type DimensionData a
  dimRules :: a -> [Rule]
  dimLangRules :: Lang -> a -> [Rule]
  dimLocaleRules :: Region -> a -> [Rule]
  dimDependents :: a -> HashSet (Seal Dimension)

-- | GADT for differentiating between dimensions
-- Each dimension should have its own constructor and provide the data structure
-- for its parsed data
data Dimension a where
  RegexMatch :: Dimension GroupMatch
  AmountOfMoney :: Dimension AmountOfMoneyData
  CreditCardNumber :: Dimension CreditCardNumberData
  Distance :: Dimension DistanceData
  Duration :: Dimension DurationData
  Email :: Dimension EmailData
  Numeral :: Dimension NumeralData
  Ordinal :: Dimension OrdinalData
  PhoneNumber :: Dimension PhoneNumberData
  Quantity :: Dimension QuantityData
  Temperature :: Dimension TemperatureData
  Time :: Dimension TimeData
  TimeGrain :: Dimension Grain
  Url :: Dimension UrlData
  Volume :: Dimension VolumeData
  CustomDimension :: CustomDimension a => a -> Dimension (DimensionData a)

-- Show
instance Show (Dimension a) where
  show RegexMatch = "RegexMatch"
  show CreditCardNumber = "CreditCardNumber"
  show Distance = "Distance"
  show Duration = "Duration"
  show Email = "Email"
  show AmountOfMoney = "AmountOfMoney"
  show Numeral = "Numeral"
  show Ordinal = "Ordinal"
  show PhoneNumber = "PhoneNumber"
  show Quantity = "Quantity"
  show Temperature = "Temperature"
  show Time = "Time"
  show TimeGrain = "TimeGrain"
  show Url = "Url"
  show Volume = "Volume"
  show (CustomDimension d) = show d
instance GShow Dimension where gshowsPrec = showsPrec

-- TextShow
instance TextShow (Dimension a) where
  showb d = TS.fromString $ show d
instance TextShow (Seal Dimension) where
  showb (Seal d) = showb d

-- Hashable
instance Eq (Dimension a) where
  d1 == d2
    | Just Refl <- geq d1 d2 = True
    | otherwise = False

instance Hashable (Seal Dimension) where
  hashWithSalt s (Seal a) = hashWithSalt s a
instance Hashable (Dimension a) where
  hashWithSalt s RegexMatch          = hashWithSalt s (0::Int)
  hashWithSalt s Distance            = hashWithSalt s (1::Int)
  hashWithSalt s Duration            = hashWithSalt s (2::Int)
  hashWithSalt s Email               = hashWithSalt s (3::Int)
  hashWithSalt s AmountOfMoney       = hashWithSalt s (4::Int)
  hashWithSalt s Numeral             = hashWithSalt s (5::Int)
  hashWithSalt s Ordinal             = hashWithSalt s (6::Int)
  hashWithSalt s PhoneNumber         = hashWithSalt s (7::Int)
  hashWithSalt s Quantity            = hashWithSalt s (8::Int)
  hashWithSalt s Temperature         = hashWithSalt s (9::Int)
  hashWithSalt s Time                = hashWithSalt s (10::Int)
  hashWithSalt s TimeGrain           = hashWithSalt s (11::Int)
  hashWithSalt s Url                 = hashWithSalt s (12::Int)
  hashWithSalt s Volume              = hashWithSalt s (13::Int)
  hashWithSalt s (CustomDimension _) = hashWithSalt s (14::Int)
  hashWithSalt s CreditCardNumber    = hashWithSalt s (15::Int)

instance GEq Dimension where
  geq RegexMatch RegexMatch = Just Refl
  geq RegexMatch _ = Nothing
  geq CreditCardNumber CreditCardNumber = Just Refl
  geq CreditCardNumber _ = Nothing
  geq Distance Distance = Just Refl
  geq Distance _ = Nothing
  geq Duration Duration = Just Refl
  geq Duration _ = Nothing
  geq Email Email = Just Refl
  geq Email _ = Nothing
  geq AmountOfMoney AmountOfMoney = Just Refl
  geq AmountOfMoney _ = Nothing
  geq Numeral Numeral = Just Refl
  geq Numeral _ = Nothing
  geq Ordinal Ordinal = Just Refl
  geq Ordinal _ = Nothing
  geq PhoneNumber PhoneNumber = Just Refl
  geq PhoneNumber _ = Nothing
  geq Quantity Quantity = Just Refl
  geq Quantity _ = Nothing
  geq Temperature Temperature = Just Refl
  geq Temperature _ = Nothing
  geq Time Time = Just Refl
  geq Time _ = Nothing
  geq TimeGrain TimeGrain = Just Refl
  geq TimeGrain _ = Nothing
  geq Url Url = Just Refl
  geq Url _ = Nothing
  geq Volume Volume = Just Refl
  geq Volume _ = Nothing
  geq (CustomDimension (_ :: a)) (CustomDimension (_ :: b))
    | Just Refl <- eqT :: Maybe (a :~: b) = Just Refl
  geq (CustomDimension _) _ = Nothing

isDimension :: Dimension a -> Token -> Bool
isDimension dim (Token dim' _) = isJust $ geq dim dim'

data ResolvedVal
  = forall a . ( Resolve a, Eq (ResolvedValue a)
               , Show (ResolvedValue a)
               , ToJSON (ResolvedValue a)) =>
    RVal (Dimension a) (ResolvedValue a)

deriving instance Show ResolvedVal

instance Eq ResolvedVal where
  RVal d1 v1 == RVal d2 v2
    | Just Refl <- geq d1 d2 = v1 == v2
    | otherwise = False

data Node = Node
  { nodeRange :: Range
  , token     :: Token
  , children  :: [Node]
  , rule      :: Maybe Text
  } deriving (Eq, Generic, Hashable, Show, NFData)

data ResolvedToken = Resolved
  { range :: Range
  , node :: Node
  , rval :: ResolvedVal
  , isLatent :: Bool
  } deriving (Eq, Show)

instance Ord ResolvedToken where
  compare (Resolved range1 _ (RVal _ v1) latent1)
          (Resolved range2 _ (RVal _ v2) latent2) =
    case compare range1 range2 of
      EQ -> case compare (toJText v1) (toJText v2) of
        EQ -> compare latent1 latent2
        z -> z
      z  -> z


data Range = Range Int Int
  deriving (Eq, Ord, Generic, Hashable, Show, NFData)

type Production = [Token] -> Maybe Token
type Predicate = Token -> Bool
data PatternItem = Regex PCRE.Regex | Predicate Predicate

type Pattern = [PatternItem]

data Rule = Rule
  { name :: Text
  , pattern :: Pattern
  , prod :: Production
  }

instance Show Rule where
  show Rule{ name } = show name

data Entity = Entity
  { dim    :: Text
  , body   :: Text
  , value  :: ResolvedVal
  , start  :: Int
  , end    :: Int
  , latent :: Bool
  , enode  :: Node
  } deriving (Eq, Generic, Show)

instance ToJSON Entity where
  toJSON ent@Entity{value = RVal _ val} = object
    [ "dim"    .= dim ent
    , "body"   .= body ent
    , "value"  .= val
    , "start"  .= start ent
    , "end"    .= end ent
    , "latent" .= latent ent
    ]

toJText :: ToJSON x => x -> Text
toJText = Text.decodeUtf8 . LB.toStrict . encode

-- -----------------------------------------------------------------
-- Predicates helpers

regex :: String -> PatternItem
regex = Regex . R.makeRegexOpts compOpts execOpts
  where
    compOpts = PCRE.defaultCompOpt + PCRE.compCaseless + PCRE.compUTF8
    execOpts = PCRE.defaultExecOpt

dimension :: Typeable a => Dimension a -> PatternItem
dimension d = Predicate $ isDimension d

-- -----------------------------------------------------------------
-- Rule Construction helpers

singleStringLookupRule :: HashMap Text a -> Text -> (a -> Maybe Token) -> Rule
singleStringLookupRule hashMap name production = Rule
  { name
  , pattern = [ regex $ unpack regexString ]
  , prod = \case
      (Token RegexMatch (GroupMatch (match:_)):_) ->
        HashMap.lookup (toLower match) hashMap >>= production
      _ -> Nothing
  }
  where
    regexString =
      "(" <> mconcat
      (intersperse "|" $ sortOn (negate . TT.length) $ HashMap.keys hashMap)
      <> ")"
