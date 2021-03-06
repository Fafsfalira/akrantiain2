{-# OPTIONS -Wall -fno-warn-unused-do-bind #-}

module Akrantiain.Sents_to_rules
(sents_to_func
) where
import Prelude hiding (undefined)
import Akrantiain.Structure
import Akrantiain.Errors
import Control.Monad(forM,when)
import Akrantiain.Pattern_match
import Data.List(group, sort, intercalate)
import qualified Data.Map as M

type Input = String
type Output = Either RuntimeError String



sents_to_func :: Set Sentence -> (Either SemanticError (Input -> Output))
sents_to_func sents = do
 (env,rules) <- sentences_to_rules sents
 return $ cook (env,rules)

split3 :: [Sentence] -> ([Conversion],[Identifier],[Define])
split3 [] = ([],[],[])
split3 (Left'   c:xs) = let (cs,is,ds) = split3 xs in (c:cs,is,ds)
split3 (Middle' i:xs) = let (cs,is,ds) = split3 xs in (cs,i:is,ds)
split3 (Right'  d:xs) = let (cs,is,ds) = split3 xs in (cs,is,d:ds)

sentences_to_rules :: [Sentence] -> Either SemanticError (Environment,[Rule])
sentences_to_rules sents = do
 let (convs, vars_pre, defs_pre) = split3 sents
 let defs = map (\(Define a b) -> (a,b)) $ defs_pre
 let vars = M.fromList $ zip vars_pre (repeat ())
 let duplicates = (map head . filter (\x -> length x > 1) . group . sort . map fst) defs
 when (not $ null duplicates) $ Left E{errNum = 334, errStr = "duplicate definition regarding identifier(s) {" ++ intercalate "}, {" (map unId duplicates) ++ "}"}
 let defs_ = M.fromList defs
 let punct = case Id "PUNCTUATION" `M.lookup` defs_ of{Nothing -> "";
  Just (Ch arr) -> arr >>= unQ} -- FIXME: THIS CONCAT ISN'T RIGHT
 rules <- forM convs $ \conv@(Conversion{lneg=left, mid=midd, rneg=right, phons=phonemes}) -> do
  let solve = resolve_select defs_
  left'  <- solve `foo` left
  right' <- solve `foo` right
  midd' <- mapM solve midd -- midd' :: [Either Boundary_ (Choose String)]
  case zipEither midd' (map phon_to_w phonemes) of
   Nothing -> Left E{errNum = 333, errStr = "mismatched number of concrete terms in left- and right-hand side of:\n" ++ toSource conv}
   Just newmidd -> return R{leftneg = fmap no' left', middle = newmidd, rightneg = fmap no' right'}
 return(Env{pun=punct, bools=vars},rules)

foo :: (a -> Either c b) -> Maybe a -> Either c (Maybe b)
foo _ Nothing = Right Nothing
foo f (Just a) = do 
 b <- f a
 return $ Just b
 
zipEither :: [Either a b] -> [c] -> Maybe [Either a (b,c)]
zipEither [] [] = Just []
zipEither [] _ = Nothing
zipEither (Left a:xs) cs = (Left a :) <$> zipEither xs cs
zipEither (Right _:_) [] = Nothing
zipEither (Right b:xs) (c:cs) = (Right (b,c) :) <$> zipEither xs cs

resolve_select :: M.Map Identifier (Choose Quote) -> Select -> Either SemanticError (Either Boundary_ (Choose String))
resolve_select _ Boundary2 = return $ Left ()
resolve_select _ (Pipe(Ch quotes)) = return $ (Right . Ch . map unQ) quotes
resolve_select defs (Iden iden) = case iden `M.lookup` defs of
 Nothing -> Left E{errNum = 335, errStr = "unresolved identifier {" ++ unId iden ++ "}"}
 Just (Ch quotes) -> return $ (Right . Ch . map unQ) quotes

phon_to_w :: Phoneme -> W
phon_to_w Dollar = Dollar_
phon_to_w (Slash str) = W str


