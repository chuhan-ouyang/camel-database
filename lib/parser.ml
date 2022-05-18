open Type
open Tokenizer
open Controller
open Helper

exception Malformed of string
exception Empty

(** General Helpers within Parser *)
let rec terminal_to_string (tokens : terminal list) =
  (match tokens with
  | [] -> ""
  | String s :: t -> s ^ " " ^ terminal_to_string t
  | Int i :: t -> string_of_int i ^ " " ^ terminal_to_string t
  | Float f :: t -> string_of_float f ^ " " ^ terminal_to_string t)
  |> String.trim

let tokens_to_terminals tokens =
  List.map
    (fun t ->
      match t with
      | Terminal x -> x
      | _ -> raise (Malformed "Wrong Format in CREATE"))
    tokens

let token_to_terminal t =
  match t with
  | Terminal terminal -> terminal
  | _ -> raise (Malformed "not a terminal")

let token_list_to_terminal_list l =
  List.map (fun x -> token_to_terminal x) l

(** [explode s] turn a string into a list of characters*)
let explode (s : string) : char list =
  List.init (String.length s) (String.get s)

(** [find elt lst] find the index of the first elt in the list*)
let rec find elt lst =
  match lst with
  | [] ->
      raise (Malformed "command does not have the correct subcommand")
  | h :: t -> if h = elt then 0 else 1 + find elt t

(** [get_odd_elem] lst return only the odd elements of a given list*)
let get_odd_elem (lst : token list) : token list =
  List.filter (fun elt -> find elt lst mod 2 = 1) lst

(** [get_even_elem] lst return only the even elements of a given list*)
let get_even_elem (lst : token list) : token list =
  List.filter (fun elt -> find elt lst mod 2 = 0) lst

(** [remove_char c s] remove any instances of the character in a string *)
let remove_char (c : char) (s : string) : string =
  let char_list = explode s in
  let filtered_list =
    List.filter (fun letter -> letter <> c) char_list
  in
  List.fold_left (fun acc h -> acc ^ String.make 1 h) "" filtered_list

(** [trim_string s] remove all the () and , in a string *)
let trim_string (s : string) =
  s |> remove_char '(' |> remove_char ')' |> remove_char ','
  |> remove_char '\'' |> String.trim

let rec terminal_to_string_list (tokens : terminal list) : string list =
  match tokens with
  | [] -> []
  | String s :: t -> trim_string s :: terminal_to_string_list t
  | Int i :: t -> string_of_int i :: terminal_to_string_list t
  | Float f :: t -> string_of_float f :: terminal_to_string_list t

let rec sublist i j l =
  match l with
  | [] -> raise (Malformed "empty list")
  | h :: t ->
      let tail = if j = 0 then [] else sublist (i - 1) (j - 1) t in
      if i > 0 then tail else h :: tail

(** [get_val_index tokens] get the index of the occurence token
    SubCommand Values in a tokens list *)
let rec get_val_index (tokens : token list) : int =
  find (SubCommand Values) tokens

(** [parse_table tokens sub_command] is a helper function that parses
    table name based on a sub_command keyword*)
let parse_table (tokens : token list) (sub_command : token) =
  match tokens with
  | [] -> raise (Malformed "wrong command format")
  | h :: t ->
      if h = sub_command then
        terminal_to_string [ List.nth t 0 |> token_to_terminal ]
        |> trim_string
      else raise (Malformed "wrong command format")

let rec parse_table_select (tokens : token list) =
  match tokens with
  | [] -> raise (Malformed "wrong command format")
  | h :: t ->
      if h = SubCommand From then
        terminal_to_string [ List.nth t 0 |> token_to_terminal ]
        |> trim_string
      else parse_table_select t

(** [get_list_after_where tokens] return the sublist of tokens after the
    where keyword*)
let get_list_after_where (tokens : token list) : token list =
  let where_index = find (SubCommand Where) tokens in
  sublist (where_index + 1) (List.length tokens - 1) tokens

(** [parse_cols col_tokens] return the list of columns to according to
    the tokens*)
let parse_cols (cols_tokens : terminal list) : string list =
  cols_tokens |> terminal_to_string_list

(** [parse_select_columns tokens] convert list of tokens involving
    column names into a list of column names (with stripping). (used for
    select) *)
let parse_select_columns tokens =
  print_endline
    ("\n The columns are parsed as: "
    ^ terminal_to_string (List.rev tokens));
  let lst =
    tokens |> List.rev |> terminal_to_string
    |> String.split_on_char ','
    |> List.map String.trim
  in
  print_endline "\nThe columns after splitting and trimming are: ";
  print_list (fun x -> "\"" ^ x ^ "\"") lst;
  lst

let extract_name token =
  match token with
  | Terminal (String s) -> trim_string s
  | Terminal (Int i) -> string_of_int i
  | Terminal (Float f) -> string_of_float f
  | _ -> raise (Malformed "Invalid Column Name.")

(** [parse_vals vals_tokens] return a list of values to insert into
    columns *)
let parse_vals (vals_tokens : terminal list) : string list =
  vals_tokens |> terminal_to_string_list

(** [get_cols_list tokens] only return the list of terminals associated
    with columns *)
let get_cols_list (tokens : token list) : string list =
  let sub_list =
    let val_index = get_val_index tokens in
    sublist 2 (val_index - 1) tokens
  in
  terminal_to_string_list (token_list_to_terminal_list sub_list)

(** converts a token to a terminal string/int/float*)
let token_to_terminal (t : token) : terminal =
  match t with
  | Terminal t -> t
  | _ -> raise (Malformed "not a terminal")

(**[get_vals_list tokens] only return the list of temrinals associated
   with values*)
let get_vals_list (tokens : token list) : terminal list =
  let sublist =
    let val_index = get_val_index tokens in
    sublist (val_index + 1) (List.length tokens - 1) tokens
  in
  List.map (fun elt -> elt |> token_to_terminal) sublist

(** [get_update_list tokens] return the sublist that contain columns and
    values to update*)
let get_update_list (tokens : token list) : token list =
  let set_index = find (SubCommand Set) tokens in
  let where_index = find (SubCommand Where) tokens in
  sublist (set_index + 1) (where_index - 1) tokens

(** [check_update_list] update_list return true if the update command is
    formatted correctly*)
let check_update_list (update_list : token list) : bool =
  let len = List.length update_list in
  len mod 3 = 0

(** [remove_eq] update_list remove the binary EQ elements in a token
    list*)
let remove_eq (update_list : token list) : token list =
  List.filter (fun elt -> elt <> BinaryOp EQ) update_list

(** [get_odd_elem] lst return only the odd elements of a given list*)
let get_odd_elem (lst : token list) : token list =
  List.filter (fun elt -> find elt lst mod 2 = 1) lst

(** [get_even_elem] lst return only the even elements of a given list*)
let get_even_elem (lst : token list) : token list =
  List.filter (fun elt -> find elt lst mod 2 = 0) lst

(** [get_update_cols update_list] return the list of columns to update.
    Precondition: the update_list is correctly formatted*)
let get_update_cols (update_list : token list) : string list =
  if not (check_update_list update_list) then raise (Malformed "TODO")
  else
    update_list |> remove_eq |> get_even_elem
    |> token_list_to_terminal_list |> terminal_to_string_list

(** [get_update_vals update_list] return the list of values to update
    for the correponding columns. Precondition: the update_list is
    correctly formatted*)
let get_update_vals (update_list : token list) : terminal list =
  if not (check_update_list update_list) then raise (Malformed "TODO")
  else
    let token_list = update_list |> remove_eq |> get_odd_elem in
    List.map (fun elt -> elt |> token_to_terminal) token_list

let get_this_command (tokens : token list) : token list =
  let eoq_index = find (EndOfQuery EOQ) tokens in
  sublist 0 (eoq_index - 1) tokens

let get_other_commands (tokens : token list) : token list =
  let eoq_index = find (EndOfQuery EOQ) tokens in
  sublist (eoq_index + 1) (List.length tokens - 1) tokens

let get_from_index (tokens : token list) : int =
  find (SubCommand From) tokens

(** [get_select_cols update_list] return the list of columns to update.
    Precondition: the update_list is correctly formatted*)
let get_select_cols (tokens : token list) : string list =
  let sub_list =
    let from_index = get_from_index tokens in
    sublist 0 (from_index - 1) tokens
  in
  terminal_to_string_list (token_list_to_terminal_list sub_list)

let rec string_formatter (lst : string list) : string list =
  List.map (fun elt -> elt |> trim_string) lst

let rec vals_formatter (lst : terminal list) : terminal list =
  match lst with
  | [] -> []
  | h :: t -> (
      match h with
      | String s -> String (trim_string s) :: vals_formatter t
      | Int i -> Int i :: vals_formatter t
      | Float f -> Float f :: vals_formatter t)

(* parse_where helpers *)

let token_to_expr_type = function
  | BinaryOp EQ -> EQ
  | BinaryOp GT -> GT
  | BinaryOp LT -> LT
  | BinaryOp GE -> GE
  | BinaryOp LE -> LE
  | BinaryOp NE -> NE
  | LogicOp AND -> AND
  | LogicOp OR -> OR
  | Terminal (String s) -> String s
  | Terminal (Int i) -> Int i
  | Terminal (Float f) -> Float f
  | _ -> raise (Malformed "token not expr_type")

let string_to_expr_type s =
  let num_int = int_of_string_opt s in
  let num_float = float_of_string_opt s in
  match (num_int, num_float) with
  | None, None -> String s
  | Some num_int, None -> Int num_int
  | None, Some num_float -> Float num_float
  | Some num_int, Some num_float -> Int num_int

let rec expression_or_helper
    (tokens : expr_type list)
    (acc : expr_type list) : expr_type list list =
  match tokens with
  | OR :: t -> [ List.rev acc ] @ expression_or_helper t []
  | [] -> [ List.rev acc ]
  | x :: xs -> expression_or_helper xs (x :: acc)

(** [expression_or tokens] seperate [tokens] by OR operator and return a
    list of conditions connected only by and. Cut [A;OR;B;OR;C] into
    [\[A\];\[B\];\[C\]] *)
let expressions_or (tokens : expr_type list) : expr_type list list =
  expression_or_helper tokens []

let and_condition_evaluater_helper
    (a : expr_type)
    (op : expr_type)
    (b : expr_type)
    (data : expr_type * expr_type) : bool =
  let data_a, data_b = data in
  match op with
  | EQ -> data_b = b
  | GT -> data_b > b
  | LT -> data_b < b
  | GE -> data_b >= b
  | LE -> data_b <= b
  | NE -> data_b <> b
  | _ -> raise (Malformed "condition not filtered right")

(** [and_conditino_evaluater a op b pair_data] evaluate a single
    condition with only one and [a op b] and see if [pair_data] have
    satisfy this condition. Return true if satisfied, false otherwise *)
let rec and_condition_evaluater
    a
    op
    b
    (pair_data : (expr_type * expr_type) list) =
  match pair_data with
  | [] -> raise (Malformed "data base type not found")
  | (data_a, data_b) :: t ->
      if data_a = a then
        and_condition_evaluater_helper a op b (data_a, data_b)
      else and_condition_evaluater a op b t

(** [evaluate_and_helper and_lst pair_data] evaluate a list of and
    conditions [and_lst] and see if [pair_data] satisfy this condition.
    Return true if satisfied, false otherwise *)
let rec evaluate_and_helper and_lst pair_data : bool =
  match and_lst with
  | [] -> true
  | AND :: t -> evaluate_and_helper t pair_data
  | a :: op :: b :: t ->
      and_condition_evaluater a op b pair_data
      && evaluate_and_helper t pair_data
  | _ -> raise (Malformed "invalid list of and conditions")

(** [evaluate_and or_lst pair_data] evaluate a list of conditions
    [or_lst] with or connected between each conditions that are only
    connected by and, and see if [pair_data] satisfy any of these
    conditions. True if yes and false if no *)
let rec evaluate_or or_lst pair_data : bool =
  match or_lst with
  | [] -> false
  | h :: t -> evaluate_and_helper h pair_data || evaluate_or t pair_data

(** [parse_where_helper tokens pair_data] evaluate conditions [tokens]
    and see if [pair_data] satisfy any of these conditions. True if yes
    and false if no *)
let parse_where_helper
    (tokens : expr_type list)
    (pair_data : string list * string list) : bool =
  let pair_data_a, pair_data_b = pair_data in
  let pair_data' =
    List.combine
      (List.map string_to_expr_type pair_data_a)
      (List.map string_to_expr_type pair_data_b)
  in
  let or_lst = expressions_or tokens in
  evaluate_or or_lst pair_data'

let print_condition = false

let rec print_function_helper exprs =
  match exprs with
  | AND :: t ->
      print_string "AND ";
      print_function_helper t
  | OR :: t ->
      print_string "OR ";
      print_function_helper t
  | EQ :: t ->
      print_string "= ";
      print_function_helper t
  | GT :: t ->
      print_string "> ";
      print_function_helper t
  | LT :: t ->
      print_string "< ";
      print_function_helper t
  | GE :: t ->
      print_string ">= ";
      print_function_helper t
  | LE :: t ->
      print_string "<= ";
      print_function_helper t
  | NE :: t ->
      print_string "!= ";
      print_function_helper t
  | String s :: t ->
      print_string s;
      print_string " ";
      print_function_helper t
  | Int i :: t ->
      print_int i;
      print_string " ";
      print_function_helper t
  | Float f :: t ->
      print_float f;
      print_string " ";
      print_function_helper t
  | [] -> print_string ""

let print_function exprs =
  print_string "Condition: ";
  print_function_helper exprs

(** see mli file for details discription *)
let parse_where (tokens : token list) =
  let exprs = List.map token_to_expr_type tokens in
  if print_condition then print_function exprs else print_string "";
  parse_where_helper exprs

(* end of parse_where *)

let parse_datatype token : data_type =
  match extract_name token with
  | "INTEGER" -> Int
  | "INT" -> Int
  | "FLOAT" -> Float
  | "DOUBLE" -> Float
  | "CHAR" -> String
  | "TEXT" -> String
  | "VARCHAR" -> String
  | _ -> raise (Malformed "Not a valid datatype of column")

let rec parse_create db tokens =
  let this_command = get_this_command tokens in
  let other_commands = get_other_commands tokens in
  try
    let name = extract_name (List.hd this_command) in
    let tail = List.tl this_command in
    let cols = tail |> get_even_elem |> List.map extract_name in
    let types = tail |> get_odd_elem |> List.map parse_datatype in
    if List.length cols = List.length types then
      let updated_db = create db name cols types in
      parse_query updated_db other_commands
    else raise (Malformed "Not correct number of columns / types")
  with Failure _ -> raise (Malformed "Syntax in Create is malformed")

(* Parse Select Functions: *)

(** acc is accumulator, cols is token list of columns, from_lst is token
    list for parse_from, lst is the list containing parse_where and so
    on. *)
and get_where db acc cols from_lst lst =
  match lst with
  | [] -> raise (Malformed "No condition after WHERE")
  | EndOfQuery EOQ :: t ->
      select db
        (terminal_to_string from_lst)
        (parse_select_columns cols)
        (parse_where acc);
      parse_query db t
  | h :: t -> get_where db (h :: acc) cols from_lst t

and get_from db acc cols lst =
  match lst with
  | [] -> raise (Malformed "No restrictions after FROM")
  | SubCommand Where :: t -> get_where db [] cols acc t
  | EndOfQuery EOQ :: t ->
      print_endline ("table num: " ^ string_of_int db.num_tables);
      select db (terminal_to_string acc) (parse_select_columns cols)
        (fun _ -> true);
      parse_query db t
  | Terminal h :: t -> get_from db (h :: acc) cols t
  | _ -> raise (Malformed "Wrong Syntax in FROM")

(*TODO: print test what columns are passed in, and there is something
  wrong with db passage. print num_tables. *)

and get_cols db acc lst =
  match lst with
  | [] -> raise (Malformed "No FROM statement after SELECT")
  | SubCommand From :: t -> get_from db [] acc t
  | Terminal h :: t -> get_cols db (h :: acc) t
  | _ -> raise (Malformed "Wrong Syntax in SELECT")

and parse_select db tokens =
  match tokens with
  | [] -> raise (Malformed "No column list after SELECT")
  | Terminal s :: t -> get_cols db [] (Terminal s :: t)
  | _ -> raise (Malformed "Wrong Syntax in SELECT")

and parse_select_new db tokens =
  let this_command = get_this_command tokens in
  let select_cols = get_select_cols tokens in
  let table = parse_table_select this_command in
  try
    let filtering_function =
      parse_where (this_command |> get_list_after_where)
    in
    Controller.select db table select_cols filtering_function;
    db
  with Malformed _ ->
    Controller.select db table select_cols (fun _ -> true);
    get_other_commands tokens |> parse_query db

(** Parse Drop: *)
and parse_drop db tokens =
  match tokens with
  | [] -> raise (Malformed "No table name after DROP")
  | Terminal s :: t ->
      let rec grouping acc lst =
        match lst with
        | [] -> raise (Malformed "Wrong Syntax in DROP")
        | EndOfQuery EOQ :: t ->
            let updated_db = drop db (terminal_to_string acc) in
            parse_query updated_db t
        | Terminal h :: t -> grouping (h :: acc) t
        | _ -> raise (Malformed "Wrong Syntax in DROP")
      in
      grouping [] (Terminal s :: t)
  | _ -> raise (Malformed "Wrong Syntax in DROP")

and parse_insert db (tokens : token list) =
  let this_command = get_this_command tokens in
  let table =
    parse_table this_command (SubCommand Into) |> trim_string
  in
  let cols = this_command |> get_cols_list |> string_formatter in
  let vals = this_command |> get_vals_list |> vals_formatter in
  let updated_db = insert db table cols vals in
  get_other_commands tokens |> parse_query updated_db

and parse_delete db tokens =
  let this_command = get_this_command tokens in
  let table = parse_table this_command (SubCommand From) in
  let updated_db =
    Controller.delete db table
      (parse_where (this_command |> get_list_after_where))
  in
  get_other_commands tokens |> parse_query updated_db

and parse_update db tokens =
  let this_command = get_this_command tokens in
  let table =
    terminal_to_string [ List.nth this_command 0 |> token_to_terminal ]
    |> trim_string
  in
  let updated_db =
    Controller.update db table
      (this_command |> get_update_list |> get_update_cols
     |> string_formatter)
      (this_command |> get_update_list |> get_update_vals
     |> vals_formatter)
      (parse_where (this_command |> get_list_after_where))
  in
  get_other_commands tokens |> parse_query updated_db

and parse_save db tokens =
  let this_command = get_this_command tokens in
  let table =
    terminal_to_string [ List.nth this_command 0 |> token_to_terminal ]
    |> trim_string
  in
  Controller.save db table;
  get_other_commands tokens |> parse_query db

and parse_read db tokens =
  let this_command = get_this_command tokens in
  let table =
    terminal_to_string [ List.nth this_command 0 |> token_to_terminal ]
    |> trim_string
  in
  let read_db = Controller.read db table in
  get_other_commands tokens |> parse_query read_db

and parse_query db tokens =
  match tokens with
  | [] -> db
  | Command Create :: t -> parse_create db t
  | Command Select :: t -> parse_select_new db t
  | Command Drop :: t -> parse_drop db t
  | Command Insert :: t -> parse_insert db t
  | Command Delete :: t -> parse_delete db t
  | Command Update :: t -> parse_update db t
  | Command Save :: t -> parse_save db t
  | Command Read :: t -> parse_read db t
  | _ -> raise (Malformed "Not a valid Command")

let parse (db : database) (input : string) =
  let tokens = tokenize input in
  if List.length tokens = 0 then raise Empty
  else if List.hd (List.rev tokens) <> EndOfQuery EOQ then
    raise
      (Malformed
         "No ';' after query, or no appropriate spacing between every \
          symbol")
  else parse_query db tokens