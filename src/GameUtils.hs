module GameUtils where

import System.Directory
import System.FilePath ((</>))
import System.FilePath.Windows (FilePath)
import System.IO
import System.Process
import System.Posix.Signals
import Control.Concurrent
import Control.Monad.IO.Class
import Control.Lens
import Control.Concurrent
import Brick
  ( App(..)
  , BrickEvent(..)
  , EventM
  , Next
  , AttrMap
  , AttrName
  , Widget
  , continue
  , halt
  , str
  , withBorderStyle
  , attrMap
  , attrName
  , withAttr
  , emptyWidget
  , hLimit
  , vLimit
  , vBox
  , hBox
  , on
  , customMain
  , neverShowCursor
  )

data Game = Game
  { _notes :: [[Int]]
  , _end :: Bool
  , _hit :: HitState
  , _score :: Int
  , _music :: ProcessHandle
  } 

data HitState = Perfect | Good | Miss | InitState
  deriving (Show, Eq, Ord)

data Key = KeyS | KeyJ
    deriving (Show, Eq, Ord)

getNotes :: FilePath -> IO [[Int]]
getNotes path = do
  notes <- readFile path 
  return $ read notes

isEnd :: [[Int]] -> Bool
isEnd [[], []] = True
isEnd _ = False

move :: [[Int]] -> [[Int]]
move = map (filter (>0) . map (\x -> x - 1))

initG :: IO Game
initG = do
    notes <- getNotes ("./notes" </> "song.txt")
    music <- playMusic ("./music" </> "song.mp3")
    pure $
      Game { _notes = notes
        , _end = False
        , _hit = InitState
        , _score = 0
        , _music = music
        }

playMusic :: FilePath -> IO ProcessHandle
playMusic filePath = do
    let command = "afplay"
        args = [filePath]
    (_, _, _, processHandle) <- createProcess (proc command args)
    return processHandle

stopMusic :: ProcessHandle -> IO ()
stopMusic processHandle = do
    terminateProcess processHandle
    _ <- waitForProcess processHandle
    return ()

update :: Game -> EventM () (Next Game)
update g =
  if (_end g) then do
    continue g
  else do
    let nextG = Game
                { _notes = move $ _notes g
                , _end = isEnd $ _notes g
                , _hit = if 1 `elem` concat (_notes g) then Miss else _hit g
                , _score = _score g
                , _music = _music g
                } 
    continue nextG

getIndex :: Key -> Int
getIndex k = case k of
  KeyS -> 0
  KeyJ -> 1

getHitState :: Int -> HitState
getHitState x
  | x == 1 = Perfect
  | x > 1 && x <= 4 = Good
  | otherwise = Miss

hit :: Key -> Game -> Game
hit k g =
  let i = getIndex k
      n = _notes g
  in if null (n !! i)
       then g
       else let s = getHitState (head (n !! i))
                v = case s of
                  Perfect -> 2
                  Good -> 1
                  Miss -> 0
            in Game { _notes = if s == Miss then n else n & element i %~ tail
                    , _end = _end g
                    , _hit = s
                    , _score = _score g + v
                    , _music = _music g
                    }