-- | Core Foundation Dictionaries.  They are toll-free bridged with 'NSDictionary'.
module System.CoreFoundation.Dictionary(
                    Dictionary,
                    DictionaryRef,
                    -- * Accessing elements
                    getValueCount,
                    getValue,
                    -- * Creating dictionaries
                    fromKeyValues,
                    ) where

import Foreign.Ptr
import Foreign.ForeignPtr
import Foreign.C
import Foreign (withArray, withArrayLen)
import System.IO.Unsafe (unsafePerformIO)
import System.CoreFoundation.Base
import System.CoreFoundation.Foreign
import System.CoreFoundation.Internal.TH

{- |
The CoreFoundation @CFDictionary@ type.
-}
data CFDictionary
{- |
A dictionary with keys of type @k@ and values of type @v@. Wraps
@CFDictionaryRef@.
-}
newtype Dictionary k v = Dictionary { unDictionary :: ForeignPtr CFDictionary }

-- | The CoreFoundation @CFDictionaryRef@ type.
{#pointer CFDictionaryRef as DictionaryRef -> CFDictionary#}

instance Object (Dictionary k v) where
  type Repr (Dictionary k v) = CFDictionary
  unsafeObject = Dictionary
  unsafeUnObject = unDictionary
  maybeStaticTypeID _ = Just _CFDictionaryGetTypeID

foreign import ccall "CFDictioanryGetTypeID" _CFDictionaryGetTypeID :: TypeID
instance StaticTypeID (Dictionary k v) where
  unsafeStaticTypeID _ = _CFDictionaryGetTypeID

#include <CoreFoundation/CoreFoundation.h>

{#fun unsafe CFDictionaryGetCount as getValueCount
    { withObject* `Dictionary k v' } -> `Int' #}

-- TODO: allow any old type as key?

{#fun unsafe CFDictionaryGetValue as getValue
    `(Object k, Object v)' => { withObject* `Dictionary k v' 
    , withDynObject* `k'
    } -> `Maybe v' '(maybeGetAndRetain . castPtr)'* #}

-- There's subtlety around GetValueForKey returning NULL; see the docs.
-- For now, we'll assume it acts like NSDocument and doesn't have nil values.

foreign import ccall "&" kCFTypeDictionaryKeyCallBacks :: Ptr ()
foreign import ccall "&" kCFTypeDictionaryValueCallBacks :: Ptr ()

{#fun CFDictionaryCreate as cfDictionaryCreate
    { withDefaultAllocator- `AllocatorPtr'
    , id `Ptr CFTypeRef'
    , id `Ptr CFTypeRef'
    , `Int'
    , id `Ptr ()'
    , id `Ptr ()'
    } -> `Dictionary k v' getOwned* #}

-- | Create a new immutable 'Dictionary' whose keys and values are taken from the given
-- list.
fromKeyValues :: (Object k, Object v) => [(k,v)] -> Dictionary k v
fromKeyValues kvs = unsafePerformIO $ do
    let (keys,values) = unzip kvs
    withObjects (map dyn keys) $ \ks -> do
    withArrayLen ks $ \n pks -> do
    withObjects (map dyn values) $ \vs -> do
    withArray vs $ \pvs -> do
    cfDictionaryCreate pks pvs n
        kCFTypeDictionaryKeyCallBacks
        kCFTypeDictionaryValueCallBacks
