{-
Assignment 1: An abstract machine for MinHs 
Course: Concepts of Programming Languages Design
Year: 2020/2021

Made by: Di Grandi Daniele
Student number: 7035616

I have made Task 1, 2, 3 and 4. However, when the program is tested on the test file
in task1/5_let/3_recursion/008.mhs it fails, don't really get how to fix it.
I think that the problem has to do with the lazy evaluation of functions,
probably not performed by my program? Don't really get why it doesn't works..
In the definition of the Head and Tail operators, there is an attempt to solve this problem.
-}

module MinHS.Evaluator where
import qualified MinHS.Env as E
import MinHS.Syntax
import MinHS.Pretty
import qualified Text.PrettyPrint.ANSI.Leijen as PP
import Debug.Trace

type VEnv = E.Env Value

data Value = I Integer
           | B Bool
           | Nil
           | Cons Integer Value
           -- Add other variants as needed
           | Closure VEnv Bind -- Added closure value
           | Partial Exp Value -- Added for Task 2
           deriving (Show)

instance PP.Pretty Value where
  pretty (I i) = numeric $ i
  pretty (B b) = datacon $ show b
  pretty (Nil) = datacon "Nil"
  pretty (Cons x v) = PP.parens (datacon "Cons" PP.<+> numeric x PP.<+> PP.pretty v)
  pretty _ = undefined -- should not ever be used

data Frame = BinOp1 Op Exp -- Frame for the primitive binary operators
           | BinOp2 Op Value -- Frame for the primitive binary operators
           | UnOp Op -- Frame for the primitive unary operators
           | Constructor1 Id Exp -- Frame for the lists
           | Constructor2 Id Value -- Frame for the lists
           | IfOp Exp Exp -- Frame for if then else
           | Bi Id Type [Id] Exp -- Frame for the binding
           | Ap1 Exp -- Frame for the application of functions
           | Ap2 Value -- Frame for the application of functions
           | Environ VEnv -- Frame for the environment
           | MultiLet [Bind] -- Frame for handle the multi-let expressions (Task 4)
          deriving(Show)

type Stack = [Frame] -- Definying a Stack type which is a list of Frames

data MachineState = State1 Stack Exp VEnv    -- Calculation mode
                  | State2 Stack Value VEnv  -- Return mode
                  deriving(Show)

-- do not change this definition
evaluate :: Program -> Value
evaluate [Bind _ _ _ e] = evalE e

-- do not change this definition
evalE :: Exp -> Value
evalE exp = loop (msInitialState exp)
  where 
    loop ms =  -- (trace (show ms)) $  -- uncomment this line and pretty print the machine state/parts of it to
                                            -- observe the machine states
             if (msInFinalState newMsState)
                then msGetValue newMsState
                else loop newMsState
              where
                 newMsState = msStep ms

msInitialState :: Exp -> MachineState
msInitialState exp = State1 [] exp E.empty -- Start with calculation mode, empty stack, the current expression and an empty environment

-- checks whether machine is in final state
msInFinalState :: MachineState -> Bool
msInFinalState ms = -- The machine is in final state if is in return mode, has an empty stack and the current expression is a value
  
  case ms of

    -- Check for constants, variables, etc:
    State2 [] (I n) _ -> True
    State2 [] (B x) _ -> True

    -- Check for lists:
    State2 [] Nil _ -> True
    State2 [] (Cons x y) _ -> True

    -- If not in final state:
    _ -> False

-- returns the final value, if machine in final state, Nothing otherwise
msGetValue :: MachineState -> Value
msGetValue ms = 

  case ms of

    -- Get value for constants, variables, etc:
    State2 t (I n) _ -> I n
    State2 t (B x) _ -> B x

    -- Get value for lists:
    State2 t Nil _ -> Nil
    State2 t (Cons x y) _ -> Cons x y

msStep :: MachineState -> MachineState
msStep ms =

  case ms of

    -- Constants:
    State1 t (Num n) gamma -> State2 t (I n) gamma
    State1 t (Con "True") gamma -> State2 t (B True) gamma
    State1 t (Con "False") gamma -> State2 t (B False) gamma

    -- Lists Nil + Cons:
    State1 t (Con "Nil") gamma -> State2 t Nil gamma
    State1 t (App (App (Con "Cons") x) xs) gamma -> State1 ((Constructor1 "Cons" xs):t) x gamma
    State2 ((Constructor1 "Cons" xs):t) (I x) gamma -> State1 ((Constructor2 "Cons" (I x)):t) xs gamma
    State2 ((Constructor2 "Cons" (I y)):t) Nil gamma -> State2 t (Cons y Nil) gamma
    State2 ((Constructor2 "Cons" Nil):t) (I x) gamma -> State2 t (Cons x Nil) gamma
    State2 ((Constructor2 "Cons" (I y)):t) (Cons x v) gamma -> State2 t (Cons y (Cons x v)) gamma

    -- Addition:
    State1 t (App (App (Prim Add) a) b) gamma -> State1 ((BinOp1 Add b):t) a gamma
    State2 ((BinOp1 Add b):t) (I a) gamma -> State1 ((BinOp2 Add (I a)):t) b gamma
    State2 ((BinOp2 Add (I a)):t) (I b) gamma -> State2 t (I (a + b)) gamma

    -- Subtraction:
    State1 t (App (App (Prim Sub) a) b) gamma -> State1 ((BinOp1 Sub b):t) a gamma
    State2 ((BinOp1 Sub b):t) (I a) gamma -> State1 ((BinOp2 Sub (I a)):t) b gamma
    State2 ((BinOp2 Sub (I a)):t) (I b) gamma -> State2 t (I (a - b)) gamma

    -- Multiplication:
    State1 t (App (App (Prim Mul) a) b) gamma -> State1 ((BinOp1 Mul b):t) a gamma
    State2 ((BinOp1 Mul b):t) (I a) gamma -> State1 ((BinOp2 Mul (I a)):t) b gamma
    State2 ((BinOp2 Mul (I a)):t) (I b) gamma -> State2 t (I (a * b)) gamma

    -- Division:
    State1 t (App (App (Prim Quot) a) b) gamma -> State1 ((BinOp1 Quot b):t) a gamma
    State2 ((BinOp1 Quot b):t) (I a) gamma -> State1 ((BinOp2 Quot (I a)):t) b gamma
    State2 ((BinOp2 Quot (I a)):t) (I 0) gamma -> error "runtime error: cannot divide by zero"
    State2 ((BinOp2 Quot (I a)):t) (I b) gamma -> State2 t (I (a `quot` b)) gamma

    -- Negate:
    State1 t (App (Prim Neg) e) gamma -> State1 ((BinOp1 Neg e):t) e gamma
    State2 ((BinOp1 Neg x):t) (I e) gamma -> State1 ((BinOp2 Neg (I e):t)) x gamma
    State2 ((BinOp2 Neg (I e)):t) (I x) gamma -> State2 t (I (-e)) gamma
    
    -- Modulus:
    State1 t (App (App (Prim Rem) a) b) gamma -> State1 ((BinOp1 Rem b):t) a gamma
    State2 ((BinOp1 Rem b):t) (I a) gamma -> State1 ((BinOp2 Rem (I a)):t) b gamma
    State2 ((BinOp2 Rem (I a)):t) (I 0) gamma -> error "runtime error: cannot divide by zero"
    State2 ((BinOp2 Rem (I a)):t) (I b) gamma -> State2 t (I (a `mod` b)) gamma

    -- Greater:
    State1 t (App (App (Prim Gt) a) b) gamma -> State1 ((BinOp1 Gt b):t) a gamma
    State2 ((BinOp1 Gt b):t) (I a) gamma -> State1 ((BinOp2 Gt (I a)):t) b gamma
    State2 ((BinOp2 Gt (I a)):t) (I b) gamma -> State2 t (B (a > b)) gamma

    -- Greater or equal:
    State1 t (App (App (Prim Ge) a) b) gamma -> State1 ((BinOp1 Ge b):t) a gamma
    State2 ((BinOp1 Ge b):t) (I a) gamma -> State1 ((BinOp2 Ge (I a)):t) b gamma
    State2 ((BinOp2 Ge (I a)):t) (I b) gamma -> State2  t (B (a >= b)) gamma

    -- Less:
    State1 t (App (App (Prim Lt) a) b) gamma -> State1 ((BinOp1 Lt b):t) a gamma
    State2 ((BinOp1 Lt b):t) (I a) gamma -> State1 ((BinOp2 Lt (I a)):t) b gamma
    State2 ((BinOp2 Lt (I a)):t) (I b) gamma -> State2 t (B (a < b)) gamma

    -- Less or equal:
    State1 t (App (App (Prim Le) a) b) gamma -> State1 ((BinOp1 Le b):t) a gamma
    State2 ((BinOp1 Le b):t) (I a) gamma -> State1 ((BinOp2 Le (I a)):t) b gamma
    State2 ((BinOp2 Le (I a)):t) (I b) gamma -> State2 t (B (a <= b)) gamma

    -- Equal:
    State1 t (App (App (Prim Eq) a) b) gamma -> State1 ((BinOp1 Eq b):t) a gamma
    State2 ((BinOp1 Eq b):t) (I a) gamma -> State1 ((BinOp2 Eq (I a)):t) b gamma
    State2 ((BinOp2 Eq (I a)):t) (I b) gamma -> State2 t (B (a == b)) gamma

    -- Not equal:
    State1 t (App (App (Prim Ne) a) b) gamma -> State1 ((BinOp1 Ne b):t) a gamma
    State2 ((BinOp1 Ne b):t) (I a) gamma -> State1 ((BinOp2 Ne (I a)):t) b gamma
    State2 ((BinOp2 Ne (I a)):t) (I b) gamma -> State2 t (B (a /= b)) gamma

    -- Head:
    State1 t (App (Prim Head) e) gamma -> State1 ((UnOp Head):t) e gamma
    State2 ((UnOp Head):t) Nil gamma -> error "runtime error: list is empty"
    -- State2 ((UnOp Head):t) (Closure (gamma') (Bind x tao vList body)) gamma -> State1 t (App (Prim Head) body) gamma -- added to tackle 5_let/3_recursion/008.mhs but it doesn't work!!
    State2 ((UnOp Head):t) (Cons y _) gamma -> State2 t (I y) gamma

    -- Tail:
    State1 t (App (Prim Tail) e) gamma -> State1 ((UnOp Tail):t) e gamma
    State2 ((UnOp Tail):t) Nil gamma -> error "runtime error: list is empty"
    -- State2 ((UnOp Tail):t) (Closure (gamma') (Bind x tao vList body)) gamma -> State1 t (App (Prim Tail) body) gamma -- added to tackle 5_let/3_recursion/008.mhs but it doesn't work!!
    State2 ((UnOp Tail):t) (Cons _ ys) gamma -> State2 t ys gamma

    -- Null:
    State1 t (App (Prim Null) e) gamma -> State1 ((UnOp Null):t) e gamma
    State2 ((UnOp Null):t) Nil gamma -> State2 t (B True) gamma
    State2 ((UnOp Null):t) _ gamma -> State2 t (B False) gamma

    -- If then else:
    State1 t (If e1 e2 e3) gamma -> State1 ((IfOp e2 e3):t) e1 gamma
    State2 ((IfOp e2 e3):t) (B True) gamma -> State1 t e2 gamma
    State2 ((IfOp e2 e3):t) (B False) gamma -> State1 t e3 gamma

    -- Variables:
    State1 t (Var x) gamma -> case (E.lookup gamma x) of
                                      Just v -> State2 t v gamma
                                      _ -> error "runtime error: undefined variable"

    -- Let bindings:
    State1 t (Let [Bind x tao vList e1] e3) gamma -> State1 ((Bi x tao vList e3):t) e1 gamma
    
    -- Update the environment & first part of Task 4:
    State2 ((Bi x tao vList e3):(Bi vname' tao' vList' e2):(MultiLet bs):t) val gamma -> State1 t (Let ((Bind vname' tao' vList' e2):bs) e3) (E.add gamma (x, val))
    State2 ((Bi x tao vList e3):t) val gamma -> State1 t e3 (E.add gamma (x, val))

    -- Second part of Task 4:
    State1 t (Let ((Bind vname tao vList e1):(Bind vname' tao' vList' e2):bs) e3) gamma -> State1 ((Bi vname' tao' vList' e2):(MultiLet bs):t) (Let [Bind vname tao vList e1] e3) gamma

    -- Task 2:
    State1 t (Recfun (Bind x tao [] (App (Prim op) e))) gamma -> State2 t (Closure (gamma) (Bind x tao [""] (App (App (Prim op) e) (Var "")))) gamma
    -- ADDED CODE TO DEAL WITH PARTIAL APPLICATION WITHOUT RECFUN (ALWAYS TASK 2):
    State1 ((Ap2 val):t) (Prim op) gamma -> State2 t (Partial (Prim op) val) gamma
    State2 ((Ap2 (I val1)):t) (Partial (Prim op) (I val2)) gamma -> State2 ((BinOp2 op (I val2)):t) (I val1) gamma
    State1 ((Ap2 val):t) (Con "Cons") gamma -> State2 t (Partial (Con "Cons") val) gamma
    State2 ((Ap2 val1):t) (Partial (Con "Cons") (I val2)) gamma -> State2 t (Cons val2 val1) gamma

    -- Task 3:
    State1 t (Recfun (Bind x tao vList (App expr (Var vname)))) gamma -> case ((length vList) > 1) of
      True -> State2 t (Closure (gamma) (Bind x tao [head vList] (Recfun (Bind (x ++ "'") tao (tail vList) (App expr (Var vname)))))) gamma
      False -> State2 t (Closure (gamma) (Bind x tao vList (App expr (Var vname)))) gamma

    -- Recfun:
    State1 t (Recfun (Bind x tao vList body)) gamma -> State2 t (Closure (gamma) (Bind x tao vList body)) gamma

    -- Apply:
    State1 t (App e1 e2) gamma -> State1 ((Ap1 e1):t) e2 gamma
    State2 ((Ap1 e1):t) val gamma -> State1 ((Ap2 val):t) e1 gamma
    State2 ((Ap2 val):t) (Closure (gamma') (Bind x tao vList body)) gamma -> State1 ((Environ gamma):t) body (E.addAll gamma' [((head vList), val), (x, Closure (gamma') (Bind x tao vList body))])
    State2 ((Environ gamma):t) body_evaluated gamma'' -> State2 t body_evaluated gamma
