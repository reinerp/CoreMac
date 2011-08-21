-- | Interface to CoreFoundation's @CFData@ C type.  It is toll-free bridged with the @NSData@ type.
module System.CoreFoundation.Data(
                Data,
                DataRef,
                getLength,
                withData,
                newData,
                getByteString,
                ) where

-- TODO:
--  - lazy bytestrings?
--  - Int (haskell) index vs Int32 (CoreFoundatino) index?
--  - some safe way to use CFDataCreateWithBytesNoCopy
--  - CFDataCreate is immutable, use it to make funcs pure?
--  - Mutable data?

import Foreign
import Foreign.C
import qualified Data.ByteString as B
import qualified Data.ByteString.Unsafe as UnsafeB
import Control.Exception (finally)

import System.CoreFoundation.Base
import System.CoreFoundation.Internal.TH


#include <CoreFoundation/CoreFoundation.h>

declareCFType "Data"


{#fun unsafe CFDataGetBytePtr as getBytePtr
    { withObject* `Data'
    } -> `Ptr Word8' castPtr #}

-- | Returns the number of bytes stored in the 'Data' object.
{#fun unsafe CFDataGetLength as getLength
    { withObject* `Data'
    } -> `CFIndex' id #}

{#fun unsafe CFDataCreate as createData
    { withDefaultAllocator- `AllocatorPtr',
      castPtr `Ptr Word8',
      id `CFIndex'
    } -> `Data' getOwned* #}


-- | Directly access the internal bytes of the Data.
-- It is not safe to use the 'Ptr' outside of the block.
withData :: Data -> (Ptr Word8 -> CFIndex -> IO a) -> IO a
withData d f = do
    p <- getBytePtr d
    len <- getLength d
    f p len `finally` touchObject d

-- | Makes a new copy of the given data.
getByteString :: Data -> IO B.ByteString
getByteString d = withData d $ \p n -> B.packCStringLen (castPtr p, cvtEnum n)

-- | Makes a new Data object with a copy of the ByteString's data.
newData :: B.ByteString -> IO Data
newData b = UnsafeB.unsafeUseAsCStringLen b $ \(p,len) ->
                        createData (castPtr p) (toEnum len)
