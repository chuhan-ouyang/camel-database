(** Representation of dynamic adventure state. *)
open Type

open Format
open Rep
open Tree

let debug = false
let print = true

let terminal_to_string (terminal : terminal) =
  match terminal with
  | Int t -> string_of_int t
  | Float t -> string_of_float t
  | String t -> t

let terminal_list_to_string_list (tlist : terminal list) =
  List.map terminal_to_string tlist

let get_new_db_create db table_name cols data_types =
  let new_db =
    create_table db table_name (List.combine cols data_types)
  in
  if print then
    print_endline
      (pretty_print
         (select new_db table_name cols (fun (_, _) -> true)))
  else ();
  new_db

let create
    (db : database)
    (table_name : string)
    (cols : string list)
    (data_types : data_type list) =
  try get_new_db_create db table_name cols data_types
  with IllegalName ->
    print_endline
      (table_name
     ^ " is already a table in the current database. Please reenter.");
    db

let get_insert_new_db db table_name cols value_list =
  let new_db =
    insert_row db table_name
      (List.combine cols (terminal_list_to_string_list value_list))
  in
  if print then
    let key =
      get_key
        (fun (table, index) -> table.table_name = table_name)
        new_db.tables
    in
    let new_table = get key new_db.tables in
    print_endline (pretty_print new_table)
  else ();
  new_db

let insert (db : database) table_name cols value_list =
  try get_insert_new_db db table_name cols value_list with
  | Invalid_argument _ ->
      print_endline
        "There is a mismatch between the number of columns specified \
         and the number of values inserted.";
      db
  | ColumnDNE ->
      print_endline
        "Some columns of the insertion attempt is not in the table.";
      db
  | WrongType ->
      print_endline
        "The value inserted is not compatible with column type.";
      db

let select (db : database) table_name cols filter_function =
  try
    let table = Rep.select db table_name cols filter_function in
    print_endline (pretty_print table)
  with
  | TableDNE ->
      print_endline (table_name ^ " is not in the current database.")
  | ColumnDNE ->
      print_endline
        "Some columns of the select attempt is not in the table."

let delete (db : database) table_name filtering_function =
  try
    let new_db = delete_row db table_name filtering_function in
    if print then
      let key =
        get_key
          (fun (table, index) -> table.table_name = table_name)
          new_db.tables
      in
      let new_table = get key new_db.tables in
      print_endline (pretty_print new_table)
    else ();
    new_db
  with TableDNE ->
    print_endline
      "The table in the delete attempt is not in the current database.";
    db

let get_update_new_db db table_name cols values filtering_function =
  let new_db =
    update_row db table_name
      (List.combine cols (terminal_list_to_string_list values))
      filtering_function
  in
  if print then
    let key =
      get_key
        (fun (table, index) -> table.table_name = table_name)
        new_db.tables
    in
    let new_table = get key new_db.tables in
    print_endline (pretty_print new_table)
  else ();
  new_db

let update (db : database) table_name cols values filtering_function =
  try
    get_update_new_db db table_name cols values filtering_function
  with
  | TableDNE ->
      print_endline
        "The table in the update attempt is not in the current \
         database.";
      db
  | ColumnDNE ->
      print_endline
        "Some columns of the update attempt is not in the table.";
      db
  | WrongType ->
      print_endline "Value updated is not compatible with column type.";
      db

let drop (db : database) table_name =
  try drop_table db table_name
  with TableDNE ->
    print_endline
      "The table in the drop attempt is not in the current database.";
    db

let save (db : database) table_name =
  try Save.save_file db table_name
  with TableDNE ->
    print_endline
      "The table in the save attempt is not in the current database."
