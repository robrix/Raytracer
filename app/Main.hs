module Main where

import Control.Parallel.Strategies hiding (dot)
import qualified Data.ByteString as ByteString
import Geometry.Ray
import Geometry.Sphere
import Geometry.Vector
import Image.Colour
import Image.Rendering
import Model.Scene
import System.Environment

main :: IO ()
main = do
  [path] <- getArgs
  ByteString.writeFile path . toPPM . render $ Scene Sphere { getCentre = Vector 0 0 10, getRadius = 250 }

render :: Scene -> Rendering
render scene = Rendering $ withStrategy (parList rpar) $ fmap (fmap (pure . trace 8 scene)) rays
  where toRow i = fmap (toPixel i) [0..3]
        toPixel r b = [ Colour (r / 3) 0 (b / 3) 1 ]

        width = 800
        height = 600
        row y = [ Ray { getLocation = Vector x y 0, getDirection = Vector 0 0 1 } | x <- [-width / 2..width / 2] ]
        rays = row <$> [-height / 2..height / 2]

trace :: Int -> Scene -> Ray -> Sample
trace 0 _ _ = clear
trace n (Scene sphere) ray@(Ray _ d) = case intersectionsWithSphere ray sphere of
  [] -> clear
  (Intersection _ n : _) -> let v = n `dot` d in Colour (min (abs (Vector 0 0 255 `dot` n)) 255) (min (abs (Vector 0 0 255 `dot` n)) 255) (min (abs (Vector 0 0 255 `dot` n)) 255) v
