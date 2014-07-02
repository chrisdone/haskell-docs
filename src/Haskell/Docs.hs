{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE TupleSections #-}

-- | Lookup the documentation of a name in a module (and in a specific
-- package in the case of ambiguity).

module Haskell.Docs
  (module Haskell.Docs
  ,Identifier(..)
  ,PackageName(..)
  ,searchAndPrintModules
  ,searchAndPrintDoc)
  where

import           Haskell.Docs.Formatting
import           Haskell.Docs.Haddock
import           Haskell.Docs.Index
import           Haskell.Docs.Types

import           Control.Exception
import           Control.Monad
import qualified Data.HashMap.Strict as M
import           Data.List
import           Data.Ord
import           Data.Text (pack,unpack)
import qualified Data.Text.IO as T
import           GHC hiding (verbosity)
import           MonadUtils
import           Packages

-- -- | Print the documentation of a name in the given module.
searchAndPrintDoc'
  :: PackageConfigMap  -- ^ Package map.
  -> [String]          -- ^ GHC options
  -> Bool              -- ^ Print modules only.
  -> Bool              -- ^ S-expression format.
  -> Maybe PackageName -- ^ Package.
  -> Maybe ModuleName  -- ^ Module name.
  -> Identifier        -- ^ Identifier.
  -> Ghc ()
searchAndPrintDoc' pkgs gs ms ss pname mname ident =
  do (result,printPkg,printModule) <- search
     case result of
       Left err ->
         throw err
       Right (sortBy (comparing identDocPackageName) -> docs) ->
          if ss
             then printSexp (nub docs)
             else mapM_ (\(i,doc') ->
                           do when (not ms && i > 0)
                                   (liftIO (putStrLn ""))
                              printIdentDoc ms printPkg printModule doc')
                        (zip [0::Int ..] (nub docs))
  where search =
          case (pname,mname) of
            (Just p,Just m) -> fmap (,False,False) (searchPackageModuleIdent Nothing p m ident)
            (Nothing,Just m) -> fmap (,True,False) (searchModuleIdent Nothing m ident)
            _ -> fmap (,True,True) (searchIdent gs Nothing ident)

searchAndPrintDoc
  :: PackageConfigMap  -- ^ Package map.
  -> [String]          -- ^ GHC options
  -> Bool              -- ^ Print modules only.
  -> Bool              -- ^ S-expression format.
  -> Maybe PackageName -- ^ Package.
  -> Maybe ModuleName  -- ^ Module name.
  -> Identifier        -- ^ Identifier.
  -> Ghc ()
searchAndPrintDoc packagemap gs ms ss pname mname ident =
  do result <- liftIO (lookupIdent gs (pack (unIdentifier ident)))
     case result of
       Nothing ->
         throw NoFindModule
       Just packages ->
         if ms
            then forM_ (concat (map snd (M.toList packages)))
                       (\modu -> liftIO (T.putStrLn modu))
            else searchAndPrintDoc' packagemap gs ms ss pname mname ident

searchAndPrintModules :: MonadIO m => [String] -> Identifier -> m ()
searchAndPrintModules gs ident =
  do result <- liftIO (lookupIdent gs (pack (unIdentifier ident)))
     case result of
       Nothing ->
         throw NoFindModule
       Just packages ->
         forM_ (nub (concat (map snd (M.toList packages))))
               (\modu -> liftIO (T.putStrLn modu))
