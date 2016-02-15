module Geometry.Ray where

import Data.List (sort)
import Geometry.Vector
import Geometry.Sphere

data Ray = Ray { getLocation :: !Vector, getDirection :: !Vector }

data Intersection = Intersection { getGlobalCoordinates :: !Vector, getNormal :: !Vector }
  deriving (Eq, Show)

-- | Compute the set of intersections between a Ray and a Sphere as a list of Intersections in increasing order of distance.
intersectionsWithSphere :: Ray -> Sphere -> [Intersection]
intersectionsWithSphere (Ray origin direction) (Sphere centre r) = if discriminant < 0 then [] else atDistance <$> sort [ d1, d2 ]
  where d1 = negate dotted + sqrt discriminant
        d2 = negate dotted - sqrt discriminant
        translated = origin - centre
        discriminant = dotted * dotted - offset * offset + r * r
        dotted = direction `dot` translated
        offset = magnitude translated
        atDistance d = Intersection (direction + origin * fromScalar d) ((direction + origin * fromScalar d) - centre / fromScalar r)
