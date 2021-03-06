-- | Core Foundation Dictionaries.  They are toll-free bridged with 'NSDictionary'.
module System.CoreFoundation.Dictionary(
                    Dictionary,
                    DictionaryRef,
                    CFDictionary,
                    -- * Accessing elements
                    size,
                    lookup,
                    -- * Conversions
                    fromKeyValues,
                    toKeyValues,
                    ) where

import Foreign.Ptr
import Foreign.ForeignPtr
import Foreign.C
import System.IO.Unsafe (unsafePerformIO)
import System.CoreFoundation.Base
import System.CoreFoundation.Foreign
import System.CoreFoundation.Internal.Unsafe (TypeID(..))
import System.CoreFoundation.Array.Internal
import qualified Data.Vector as V
import qualified Data.Vector.Algorithms.Intro as VA
import Prelude hiding (lookup)
import Data.Typeable
import Control.DeepSeq
import Data.Ord (comparing)
import Data.List (intercalate)

{- |
The CoreFoundation @CFDictionary@ type.
-}
data CFDictionary
{- |
A dictionary with keys of type @k@ and values of type @v@. Wraps
@CFDictionaryRef@.
-}
newtype Dictionary k v = Dictionary { unDictionary :: ForeignPtr CFDictionary }
  deriving Typeable

-- | The CoreFoundation @CFDictionaryRef@ type.
{#pointer CFDictionaryRef as DictionaryRef -> CFDictionary#}

instance Object (Dictionary k v) where
  type Repr (Dictionary k v) = CFDictionary
  unsafeObject = Dictionary
  unsafeUnObject = unDictionary
  maybeStaticTypeID _ = Just _CFDictionaryGetTypeID

foreign import ccall "CFDictionaryGetTypeID" _CFDictionaryGetTypeID :: TypeID
instance StaticTypeID (Dictionary k v) where
  unsafeStaticTypeID _ = _CFDictionaryGetTypeID

#include <CoreFoundation/CoreFoundation.h>

{#fun pure unsafe CFDictionaryGetCount as size
    { withObject* `Dictionary k v' } -> `Int' #}

-- TODO: allow any old type as key?

{#fun unsafe CFDictionaryGetValue as cfGetValue
    `(Object k, Object v)' => { withObject* `Dictionary k v' 
    , withVoidObject* `k'
    } -> `Ptr ()' id #}

lookup :: (Object k, Object v) => Dictionary k v -> k -> Maybe v
lookup dict k = unsafePerformIO . maybeGetOwned . fmap castPtr $ cfGetValue dict k

-- There's subtlety around GetValueForKey returning NULL; see the docs.
-- For now, we'll assume it acts like NSDocument and doesn't have nil values.

foreign import ccall "&" kCFTypeDictionaryKeyCallBacks :: Ptr ()
foreign import ccall "&" kCFTypeDictionaryValueCallBacks :: Ptr ()

{#fun CFDictionaryCreate as cfDictionaryCreate
    { withDefaultAllocator- `AllocatorPtr'
    , id `Ptr (Ptr ())'
    , id `Ptr (Ptr ())'
    , `Int'
    , id `Ptr ()'
    , id `Ptr ()'
    } -> `DictionaryRef' id #}

-- | Create a new immutable 'Dictionary' whose keys and values are taken from the given
-- vector.
fromKeyValues :: (Object k, Object v) => V.Vector (k, v) -> Dictionary k v
fromKeyValues kvs =
  let (keys, vals) = V.unzip kvs in
  unsafePerformIO $
  withVector keys $ \pk len ->
  withVector vals $ \pv _ ->
  getOwned $ 
  cfDictionaryCreate (castPtr pk) (castPtr pv) len
    kCFTypeDictionaryKeyCallBacks
    kCFTypeDictionaryValueCallBacks

-- | Inverse of 'fromKeyValues'
toKeyValues :: (Object k, Object v) => Dictionary k v -> V.Vector (k, v)
toKeyValues d =
  uncurry V.zip $
  unsafePerformIO $
  withObject d $ \p ->
    let len = size d in
    buildVector len $ \kp ->
      fst `fmap` (buildVector len $ \vp ->
          {#call unsafe CFDictionaryGetKeysAndValues as ^ #} 
             p 
             (castPtr kp) 
             (castPtr vp)
         )

-- | 'toKeyValues', then sort ascending by key; analogous to @Data.Map.toAscList@
toAscKeyValues :: (Ord k, Object k, Object v) => Dictionary k v -> V.Vector (k, v)
toAscKeyValues = V.modify (VA.sortBy (comparing fst)) . toKeyValues

instance (Object k, Object v, Show k, Show v) => Show (Dictionary k v) where
  show = interCommas . V.map showPair . toKeyValues
    where
      showPair (k, v) = show k ++ ":" ++ show v
      interCommas = intercalate ", " . V.toList
instance (Object k, Object v, Ord k, Eq v) => Eq (Dictionary k v) where
  a == b = toAscKeyValues a == toAscKeyValues b
-- | Equality by converting to a 'Map'
instance (Object k, Object v, Ord k, Ord v) => Ord (Dictionary k v) where
  compare a b = compare (toAscKeyValues a) (toAscKeyValues b)
instance NFData (Dictionary k v)
