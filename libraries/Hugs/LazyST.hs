-----------------------------------------------------------------------------
-- Lazy State Thread module
-- 
-- This library provides support for both lazy and strict state threads,
-- as described in the PLDI '94 paper by John Launchbury and Simon Peyton
-- Jones.  In addition to the monad ST, it also provides mutable variables
-- STRef and mutable arrays STArray.  It is identical to the ST module
-- except that the ST instance is lazy.
--
-- Suitable for use with Hugs 98.
-----------------------------------------------------------------------------

module Hugs.LazyST 
	( ST
	, runST
	, unsafeRunST
	, thenLazyST, thenStrictST, returnST
	, unsafeInterleaveST
	, fixST 
	, RealWorld
	, stToIO
	, unsafeIOToST

	, State
	, STRef
	  -- instance Eq (STRef s a)
	, newSTRef
	, readSTRef
	, writeSTRef 
	, modifySTRef

        , STArray
          -- instance Eq (STArray s ix elt)
        , newSTArray
        , boundsSTArray
        , readSTArray
        , writeSTArray
        , thawSTArray
        , freezeSTArray
        , unsafeFreezeSTArray
        , Ix
	) where

import Hugs.Array(Array,Ix(index,rangeSize),assocs)
import Hugs.Array.Base(HasBounds(bounds),MArray(..))
import Hugs.IOExts(unsafePerformIO)
import Control.Monad   
import Data.Dynamic

-----------------------------------------------------------------------------

data ST s a      -- implemented as an internal primitive

primitive runST                        :: (forall s. ST s a) -> a
primitive unsafeRunST                  :: ST s a -> s -> (a, s)
primitive returnST     "STReturn"      :: a -> ST s a
primitive thenLazyST   "STLazyBind"    :: ST s a -> (a -> ST s b) -> ST s b
primitive thenStrictST "STStrictBind"  :: ST s a -> (a -> ST s b) -> ST s b
primitive unsafeInterleaveST "STInter" :: ST s a -> ST s a
primitive fixST        "STFix"         :: (a -> ST s a) -> ST s a

primitive stToIO	"primSTtoIO"   :: ST RealWorld a -> IO a

data RealWorld = RealWorld

unsafeIOToST        :: IO a -> ST s a
unsafeIOToST         = returnST . unsafePerformIO

instance Functor (ST s) where
    fmap = liftM

instance Monad (ST s) where
    (>>=)  = thenLazyST
    return = returnST

-----------------------------------------------------------------------------

type State s = s -- dummy wrapper for state to be closer to GHC interface
data STRef s a   -- implemented as an internal primitive

primitive newSTRef   "STNew"      :: a -> ST s (STRef s a)
primitive readSTRef  "STDeref"    :: STRef s a -> ST s a
primitive writeSTRef "STAssign"   :: STRef s a -> a -> ST s ()
primitive eqSTRef    "STMutVarEq" :: STRef s a -> STRef s a -> Bool

modifySTRef :: STRef s a -> (a -> a) -> ST s ()
modifySTRef ref f = writeSTRef ref . f =<< readSTRef ref

instance Eq (STRef s a) where (==) = eqSTRef

-----------------------------------------------------------------------------

data STArray s ix elt -- implemented as an internal primitive

newSTArray          :: Ix ix => (ix,ix) -> elt -> ST s (STArray s ix elt)
boundsSTArray       :: Ix ix => STArray s ix elt -> (ix, ix)
readSTArray         :: Ix ix => STArray s ix elt -> ix -> ST s elt
writeSTArray        :: Ix ix => STArray s ix elt -> ix -> elt -> ST s ()
thawSTArray         :: Ix ix => Array ix elt -> ST s (STArray s ix elt)
freezeSTArray       :: Ix ix => STArray s ix elt -> ST s (Array ix elt)
unsafeFreezeSTArray :: Ix ix => STArray s ix elt -> ST s (Array ix elt)

newSTArray bs e      = primNewArr bs (rangeSize bs) e
boundsSTArray a      = primBounds a
readSTArray a i      = primReadArr index a i
writeSTArray a i e   = primWriteArr index a i e
thawSTArray arr      = newSTArray (bounds arr) err `thenStrictST` \ stArr ->
		       let 
                         fillin [] = returnST stArr
                         fillin ((ix,v):ixvs) = writeSTArray stArr ix v
                          `thenStrictST` \ _ -> fillin ixvs
		       in fillin (assocs arr)
 where
  err = error "thawArray: element not overwritten" -- shouldnae happen
freezeSTArray a      = primFreeze a
unsafeFreezeSTArray  = freezeSTArray  -- not as fast as GHC

instance Eq (STArray s ix elt) where
  (==) = eqSTArray

instance HasBounds (STArray s) where
  bounds = boundsSTArray

primitive primNewArr   "STNewArr"
          :: (a,a) -> Int -> b -> ST s (STArray s a b)
primitive primReadArr  "STReadArr"
          :: ((a,a) -> a -> Int) -> STArray s a b -> a -> ST s b
primitive primWriteArr "STWriteArr"
          :: ((a,a) -> a -> Int) -> STArray s a b -> a -> b -> ST s ()
primitive primFreeze   "STFreeze"
          :: STArray s a b -> ST s (Array a b)
primitive primBounds   "STBounds"
          :: STArray s a b -> (a,a)
primitive eqSTArray    "STArrEq"
          :: STArray s a b -> STArray s a b -> Bool

-----------------------------------------------------------------------------

instance MArray (STArray s) e (ST s) where
	newArray = newSTArray
	readArray = readSTArray
	writeArray = writeSTArray

sTArrayTc :: TyCon
sTArrayTc = mkTyCon "STArray"

instance (Typeable a, Typeable b, Typeable c) => Typeable (STArray a b c) where
  typeOf a = mkAppTy sTArrayTc [typeOf ((undefined :: STArray a b c -> a) a),
				typeOf ((undefined :: STArray a b c -> b) a),
				typeOf ((undefined :: STArray a b c -> c) a)]