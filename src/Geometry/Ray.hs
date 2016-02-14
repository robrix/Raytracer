module Geometry.Ray where

import Data.List (sort)
import Geometry.Vector
import Geometry.Sphere

data Ray = Ray { getLocation :: !Vector, getDirection :: !Vector }

data Intersection = Intersection { getGlobalCoordinates :: !Vector, getNormal :: !Vector }

-- | Compute the set of intersections between a Ray and a Sphere as a list of Vectors in increasing order of distance.
intersectionsWithSphere :: Ray -> Sphere -> [Vector]
intersectionsWithSphere (Ray o l) (Sphere c r) = if under < 0 then [] else atDistance <$> sort [ d1, d2 ]
  where d1 = negate dotted + sqrt under
        d2 = negate dotted - sqrt under
        translated = o - c
        under = dotted * dotted - offset * offset + r * r
        dotted = l `dot` translated
        offset = magnitude translated
        atDistance d = l + o * fromScalar d
