{-# LANGUAGE DuplicateRecordFields #-}
module Model.Scene where

import Control.Monad.Random.Class (MonadRandom)
import Control.Monad.Random.Lazy
import Control.Parallel.Strategies (evalTuple2, parList, r0, rpar, using)
import Data.Array
import qualified Data.ByteString.Builder as B
import Data.List (sortOn)
import qualified Geometry.Plane as Plane
import Geometry.Ray
import qualified Geometry.Sphere as Sphere
import Image.Rendering hiding (samples)
import Linear.Affine
import Linear.Epsilon
import qualified Linear.Metric as Metric
import Linear.V2
import Linear.V3
import Linear.Vector as Linear
import Probability.Distribution
import System.IO
import System.Random (Random)
import System.Random.Mersenne.Pure64

-- | Sparse 8-tree representation for efficiently storing and querying scenes.
data Octree a
  = Empty
  | Leaf a
  | XYZ a (V2 (V2 (V2 (Octree a))))
  deriving (Eq, Ord, Show)

newtype Scene a = Scene [Model a]
  deriving (Eq, Ord, Show)

data Geometry a
  = Sphere (Sphere.Sphere a)
  | Plane (Plane.Plane a)
  deriving (Eq, Ord, Show)

data Model a = Model
  { geometry    :: Geometry a
  , emittance   :: Point V3 a
  , reflectance :: Point V3 a
  }
  deriving (Eq, Ord, Show)

data Step a = Step
  { intersection :: Intersection a
  , emittance    :: Point V3 a
  , reflectance  :: Point V3 a
  }

type Path a = [Step a]

intersections :: (Epsilon a, RealFloat a) => Geometry a -> Ray a -> [Intersection a]
intersections (Sphere sphere) = Sphere.intersections sphere
intersections (Plane plane)   = Plane.intersections plane

modelIntersections :: (Epsilon a, RealFloat a) => Model a -> Ray a -> [(Intersection a, Model a)]
modelIntersections model@(Model geometry _ _) = fmap (flip (,) model) . intersections geometry

trace :: (Epsilon a, Random a, RealFloat a) => Int -> Scene a -> Ray a -> Distribution (Sample a)
trace 0 _ _ = pure zero
trace n scene@(Scene models) ray = case models >>= sortOn (distance . fst) . flip modelIntersections ray of
  [] -> pure zero
  (Intersection _ origin normal, Model _ emittance reflectance) : _ -> do
    v <- V3 <$> UniformR (-1) 1 <*> UniformR (-1) 1 <*> UniformR (-1) 1
    let direction = Metric.normalize v
        cosTheta = direction `Metric.dot` normal
        brdf = reflectance ^/ pi
    incoming <- trace (pred n) scene (Ray origin (if cosTheta >= 0 then direction else -direction))
    pure (emittance + (brdf * incoming ^* abs cosTheta ^/ prob))
  where prob = recip (2 * pi)

render :: (Epsilon a, MonadRandom m, Random a, RealFloat a) => Size -> Int -> Scene a -> m (Rendering a)
render size@(V2 w h) n scene = do
  rays <- samples n $ do
    x <- UniformR 0 (pred w)
    y <- UniformR 0 (pred h)
    let ray = Ray (P (V3 (fromIntegral (w `div` 2 - x)) (fromIntegral (h `div` 2 - y)) (-450))) (Linear.unit _z)
    sample <- trace 8 scene ray
    pure (V2 x y, Pixel (Average 1 sample))
  pure (Rendering (accumArray (<>) mempty (0, size) (rays `using` parList (evalTuple2 r0 rpar))))

renderToFile :: (Epsilon a, Random a, RealFloat a) => Size -> Int -> FilePath -> Scene a -> IO ()
renderToFile size n path scene = do
  mt <- newPureMT
  withFile path WriteMode (\ handle -> do
    rendering <- evalRandT (render size n scene) mt
    B.hPutBuilder handle (toPPM Depth16 rendering))
