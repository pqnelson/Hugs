-----------------------------------------------------------------------------
-- Mutable arrays in the IO monad:
--
-- Suitable for use with Hugs 98.
-----------------------------------------------------------------------------

module Hugs.IOArray
	( IOArray			-- instance of: Eq, Typeable
	, newIOArray
	, boundsIOArray
	, readIOArray
	, writeIOArray
	, freezeIOArray
	, thawIOArray
	, unsafeFreezeIOArray
	) where

import Hugs.Array
import Data.Dynamic

-----------------------------------------------------------------------------

data IOArray ix elt -- implemented as an internal primitive

newIOArray          :: Ix ix => (ix,ix) -> elt -> IO (IOArray ix elt)
boundsIOArray       :: Ix ix => IOArray ix elt -> (ix, ix)
readIOArray         :: Ix ix => IOArray ix elt -> ix -> IO elt
writeIOArray        :: Ix ix => IOArray ix elt -> ix -> elt -> IO ()
thawIOArray         :: Ix ix => Array ix elt -> IO (IOArray ix elt)
freezeIOArray       :: Ix ix => IOArray ix elt -> IO (Array ix elt)
unsafeFreezeIOArray :: Ix ix => IOArray ix elt -> IO (Array ix elt)

newIOArray bs e      = primNewArr bs (rangeSize bs) e
boundsIOArray a      = primBounds a
readIOArray a i      = primReadArr index a i
writeIOArray a i e   = primWriteArr index a i e
thawIOArray arr      = do a <- newIOArray (bounds arr) err
			  let fillin []          = return a
			      fillin((ix,v):ixs) = do writeIOArray a ix v
                                                      fillin ixs
                          fillin (assocs arr)
                       where err =  error "thawArray: element not overwritten"

freezeIOArray a      = primFreeze a
unsafeFreezeIOArray  = freezeIOArray  -- not as fast as GHC

instance Eq (IOArray ix elt) where
  (==) = eqIOArray

primitive primNewArr   "IONewArr"
          :: (a,a) -> Int -> b -> IO (IOArray a b)
primitive primReadArr  "IOReadArr"
          :: ((a,a) -> a -> Int) -> IOArray a b -> a -> IO b
primitive primWriteArr "IOWriteArr"
          :: ((a,a) -> a -> Int) -> IOArray a b -> a -> b -> IO ()
primitive primFreeze   "IOFreeze"
          :: IOArray a b -> IO (Array a b)
primitive primBounds   "IOBounds"
          :: IOArray a b -> (a,a)
primitive eqIOArray    "IOArrEq"
          :: IOArray a b -> IOArray a b -> Bool

-----------------------------------------------------------------------------

iOArrayTc :: TyCon
iOArrayTc = mkTyCon "IOArray"

instance (Typeable a, Typeable b) => Typeable (IOArray a b) where
  typeOf a = mkAppTy iOArrayTc [typeOf ((undefined :: IOArray a b -> a) a),
				typeOf ((undefined :: IOArray a b -> b) a)]