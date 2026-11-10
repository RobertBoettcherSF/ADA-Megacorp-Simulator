--  Megacorp Simulator
--  Copyright (C) 2026  the Megacorp Simulator authors
--
--  This program is free software; you can redistribute it and/or
--  modify it under the terms of the GNU General Public License as
--  published by the Free Software Foundation; either version 2 of
--  the License, or (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see
--  <https://www.gnu.org/licenses/>.

with Ada.Directories;
with Ada.Text_IO;
with Megacorp.Assets.Placeholder;
with Megacorp.Data.Virtual_FS.Native;

package body Megacorp.Map is
   package Placeholder renames Megacorp.Assets.Placeholder;
   package Disk renames Megacorp.Data.Virtual_FS.Native;

   --  Below this edge the test layout is open ground only.
   Min_Pattern : constant := 8;

   type Delta_XY is record
      DX : Integer;
      DY : Integer;
   end record;

   Four_Step : constant array (Four_Way) of Delta_XY :=
     (North => (DX => 0, DY => -1),
      East  => (DX => 1, DY => 0),
      South => (DX => 0, DY => 1),
      West  => (DX => -1, DY => 0));

   Eight_Step : constant array (Eight_Way) of Delta_XY :=
     (North => (DX => 0, DY => -1),
      East => (DX => 1, DY => 0),
      South => (DX => 0, DY => 1),
      West => (DX => -1, DY => 0),
      North_East => (DX => 1, DY => -1),
      South_East => (DX => 1, DY => 1),
      South_West => (DX => -1, DY => 1),
      North_West => (DX => -1, DY => -1));

   function Step_Of (Dir : Four_Way) return Delta_XY;
   function Step_Of (Dir : Eight_Way) return Delta_XY;
   function Trim (Image : String) return String;
   function Hex_Digit (Level : Height_Level) return Character;
   function Flag_Code (Cell : Tile) return Character;
   procedure Set_Cell
     (M : in out City;
      X, Y : Positive;
      Kind : Terrain;
      Level : Height_Level);
   procedure Fill_Open (M : in out City);
   function Clamp (Value, Low, High : Integer) return Integer;
   function Touches_Road
     (M : City; X, Y : Positive) return Boolean;
   procedure Lay_River
     (M : in out City; G : in out RNG.Generator);
   procedure Lay_Roads
     (M : in out City; G : in out RNG.Generator);
   procedure Lay_Pavement (M : in out City);
   procedure Lay_Buildings
     (M : in out City; G : in out RNG.Generator);
   function Hex_Pair (Value : Natural) return String;
   function Row_Image
     (M : City;
      Y : Positive;
      Tiles : Placeholder.Tileset) return String;
   function Parent_Directory (Path : String) return String;
   procedure Write_Map_File
     (Path : String;
      Version : String;
      M : City;
      Tiles : Placeholder.Tileset);
   procedure Write_Index
     (Path : String; Version : String);
   function Bare_Directory (Directory : String) return String;

   function Layout_Seed (M : City) return RNG.Word is
   begin
      return M.From_Seed;
   end Layout_Seed;

   function In_Bounds (M : City; X, Y : Integer) return Boolean is
   begin
      return X >= 1 and then X <= M.Width
        and then Y >= 1 and then Y <= M.Height;
   end In_Bounds;

   function Tile_At (M : City; X, Y : Integer) return Tile is
   begin
      return M.Cell (X, Y);
   end Tile_At;

   function Step_Of (Dir : Four_Way) return Delta_XY is
   begin
      return Four_Step (Dir);
   end Step_Of;

   function Step_Of (Dir : Eight_Way) return Delta_XY is
   begin
      return Eight_Step (Dir);
   end Step_Of;

   function Has_Neighbour_4
     (M : City; X, Y : Integer; Dir : Four_Way) return Boolean
   is
      Step : constant Delta_XY := Step_Of (Dir);
   begin
      return In_Bounds (M, X + Step.DX, Y + Step.DY);
   end Has_Neighbour_4;

   function Neighbour_4
     (M : City; X, Y : Integer; Dir : Four_Way) return Point
   is
      Step : constant Delta_XY := Step_Of (Dir);
   begin
      return (X => X + Step.DX, Y => Y + Step.DY);
   end Neighbour_4;

   function Has_Neighbour_8
     (M : City; X, Y : Integer; Dir : Eight_Way) return Boolean
   is
      Step : constant Delta_XY := Step_Of (Dir);
   begin
      return In_Bounds (M, X + Step.DX, Y + Step.DY);
   end Has_Neighbour_8;

   function Neighbour_8
     (M : City; X, Y : Integer; Dir : Eight_Way) return Point
   is
      Step : constant Delta_XY := Step_Of (Dir);
   begin
      return (X => X + Step.DX, Y => Y + Step.DY);
   end Neighbour_8;

   function Terrain_Code (Kind : Terrain) return Character is
   begin
      case Kind is
         when Open_Ground =>
            return '.';
         when Road =>
            return '+';
         when Pavement =>
            return '=';
         when Building =>
            return 'B';
         when Water =>
            return '~';
      end case;
   end Terrain_Code;

   function Hex_Digit (Level : Height_Level) return Character is
      Hex : constant String := "0123456789ABCDEF";
   begin
      return Hex (Hex'First + Level);
   end Hex_Digit;

   function Flag_Code (Cell : Tile) return Character is
      Bits : Natural := 0;
   begin
      if Cell.Walkable then
         Bits := Bits + 1;
      end if;
      if Cell.Drivable then
         Bits := Bits + 2;
      end if;
      return Character'Val (Character'Pos ('0') + Bits);
   end Flag_Code;

   function Trim (Image : String) return String is
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;
      return Image;
   end Trim;

   procedure Set_Cell
     (M : in out City;
      X, Y : Positive;
      Kind : Terrain;
      Level : Height_Level)
   is
      Cell : Tile;
   begin
      Cell.Kind := Kind;
      Cell.Level := Level;
      Cell.Walkable := Kind in Open_Ground | Road | Pavement;
      Cell.Drivable := Kind = Road;
      M.Cell (X, Y) := Cell;
   end Set_Cell;

   procedure Fill_Open (M : in out City) is
   begin
      for Y in 1 .. M.Height loop
         for X in 1 .. M.Width loop
            Set_Cell (M, X, Y, Open_Ground, 1);
         end loop;
      end loop;
   end Fill_Open;

   function Clamp (Value, Low, High : Integer) return Integer is
   begin
      if Value < Low then
         return Low;
      elsif Value > High then
         return High;
      else
         return Value;
      end if;
   end Clamp;

   function Touches_Road
     (M : City; X, Y : Positive) return Boolean
   is
   begin
      for Dir in Four_Way loop
         if Has_Neighbour_4 (M, X, Y, Dir) then
            declare
               At_Dir : constant Point := Neighbour_4 (M, X, Y, Dir);
            begin
               if Tile_At (M, At_Dir.X, At_Dir.Y).Kind = Road then
                  return True;
               end if;
            end;
         end if;
      end loop;
      return False;
   end Touches_Road;

   procedure Lay_River
     (M : in out City; G : in out RNG.Generator)
   is
      Base   : Integer;
      Thick  : Integer;
      Center : Integer;
      Shift  : Integer;
      Top    : Integer;
      Bottom : Integer;
   begin
      Base := RNG.Pick (G, M.Height / 3, (2 * M.Height) / 3);
      Thick := RNG.Pick (G, 2, 3);
      Center := Base;
      for X in 1 .. M.Width loop
         Shift := RNG.Pick (G, -1, 1);
         Center := Clamp
           (Center + Shift, Thick, M.Height - Thick);
         Top := Center - (Thick / 2);
         Bottom := Top + Thick - 1;
         for Y in Top .. Bottom loop
            Set_Cell (M, X, Y, Water, 0);
         end loop;
      end loop;
   end Lay_River;

   procedure Lay_Roads
     (M : in out City; G : in out RNG.Generator)
   is
      Spacing : constant Integer := RNG.Pick (G, 8, 12);
      X       : Integer := 1;
      Y       : Integer := 1;
   begin
      pragma Assert (Spacing > 0);
      while X <= M.Width loop
         for Row in 1 .. M.Height loop
            Set_Cell (M, X, Row, Road, 1);
         end loop;
         X := X + Spacing;
      end loop;
      while Y <= M.Height loop
         for Column in 1 .. M.Width loop
            Set_Cell (M, Column, Y, Road, 1);
         end loop;
         Y := Y + Spacing;
      end loop;
   end Lay_Roads;

   procedure Lay_Pavement (M : in out City) is
   begin
      for Y in 1 .. M.Height loop
         for X in 1 .. M.Width loop
            if M.Cell (X, Y).Kind = Open_Ground
              and then Touches_Road (M, X, Y)
            then
               Set_Cell (M, X, Y, Pavement, 1);
            end if;
         end loop;
      end loop;
   end Lay_Pavement;

   procedure Lay_Buildings
     (M : in out City; G : in out RNG.Generator)
   is
      Storey : Integer;
   begin
      for Y in 1 .. M.Height loop
         for X in 1 .. M.Width loop
            if M.Cell (X, Y).Kind = Open_Ground then
               Storey := RNG.Pick (G, 2, 5);
               Set_Cell (M, X, Y, Building, Storey);
            end if;
         end loop;
      end loop;
   end Lay_Buildings;

   function Test_Layout
     (From : RNG.Word; Width, Height : Positive) return City
   is
      Result : City (Width, Height);
      World  : constant RNG.Generator := RNG.Make (From);
      Stream : RNG.Generator :=
        RNG.Child (World, RNG.City, 1);
   begin
      Result.From_Seed := From;
      Fill_Open (Result);
      if Width >= Min_Pattern and then Height >= Min_Pattern then
         Lay_River (Result, Stream);
         Lay_Roads (Result, Stream);
         Lay_Pavement (Result);
         Lay_Buildings (Result, Stream);
      end if;
      return Result;
   end Test_Layout;

   function Test_Layout
     (From : RNG.Word;
      Size : Parameters.Generator_Parameters) return City
   is
   begin
      return Test_Layout
        (From,
         Parameters.City_Map_Width (Size),
         Parameters.City_Map_Height (Size));
   end Test_Layout;

   procedure Put_Window
     (M : City;
      First_X, First_Y : Positive;
      Columns, Rows : Natural)
   is
      Last_X : constant Integer :=
        Integer'Min (M.Width, First_X + Columns - 1);
      Last_Y : constant Integer :=
        Integer'Min (M.Height, First_Y + Rows - 1);
   begin
      for Y in First_Y .. Last_Y loop
         for X in First_X .. Last_X loop
            Ada.Text_IO.Put
              (Terrain_Code (Tile_At (M, X, Y).Kind));
         end loop;
         Ada.Text_IO.New_Line;
      end loop;
   end Put_Window;

   procedure Put_Sample (M : City) is
      Found   : Boolean := False;
      At_X    : Positive := 1;
      At_Y    : Positive := 1;
      First_X : Positive;
      First_Y : Positive;
   begin
      Ada.Text_IO.Put_Line ("northwest:");
      Put_Window (M, 1, 1, 36, 10);
      for Y in 1 .. M.Height loop
         for X in 1 .. M.Width loop
            if M.Cell (X, Y).Kind = Water and then not Found then
               Found := True;
               At_X := X;
               At_Y := Y;
            end if;
         end loop;
      end loop;
      if Found then
         Ada.Text_IO.Put_Line
           ("river near" & Integer'Image (At_X)
            & Integer'Image (At_Y) & ":");
         First_X := Positive (Integer'Max (1, At_X - 17));
         First_Y := Positive (Integer'Max (1, At_Y - 3));
         Put_Window (M, First_X, First_Y, 36, 8);
      end if;
   end Put_Sample;

   function Hex_Pair (Value : Natural) return String is
      Hex : constant String := "0123456789ABCDEF";
   begin
      return Hex (Hex'First + Value / 16)
        & Hex (Hex'First + Value mod 16);
   end Hex_Pair;

   function Row_Image
     (M : City;
      Y : Positive;
      Tiles : Placeholder.Tileset) return String
   is
      Image : String (1 .. M.Width * 5);
      Place : Positive := 1;
      Cell  : Tile;
      Id    : Natural;
   begin
      for X in 1 .. M.Width loop
         Cell := M.Cell (X, Y);
         Id := Placeholder.Tile_Id (Tiles, Cell.Kind, Cell.Level);
         Image (Place) := Terrain_Code (Cell.Kind);
         Image (Place + 1) := Hex_Digit (Cell.Level);
         Image (Place + 2) := Flag_Code (Cell);
         Image (Place + 3) := Hex_Pair (Id) (1);
         Image (Place + 4) := Hex_Pair (Id) (2);
         Place := Place + 5;
      end loop;
      return Image;
   end Row_Image;

   procedure Write_Map_File
     (Path : String;
      Version : String;
      M : City;
      Tiles : Placeholder.Tileset)
   is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "{");
      Ada.Text_IO.Put_Line
        (File, "  ""version"": """ & Version & """,");
      Ada.Text_IO.Put_Line
        (File,
         "  ""seed"": " & Trim (RNG.Word'Image (Layout_Seed (M)))
         & ",");
      Ada.Text_IO.Put_Line
        (File, "  ""width"": " & Trim (Integer'Image (M.Width)) & ",");
      Ada.Text_IO.Put_Line
        (File,
         "  ""height"": " & Trim (Integer'Image (M.Height)) & ",");
      Ada.Text_IO.Put_Line (File, "  ""legend"": {");
      Ada.Text_IO.Put_Line (File, "    ""."": ""open"",");
      Ada.Text_IO.Put_Line (File, "    ""+"": ""road"",");
      Ada.Text_IO.Put_Line (File, "    ""="": ""pavement"",");
      Ada.Text_IO.Put_Line (File, "    ""B"": ""building"",");
      Ada.Text_IO.Put_Line (File, "    ""~"": ""water""");
      Ada.Text_IO.Put_Line (File, "  },");
      Ada.Text_IO.Put_Line (File, "  ""rows"": [");
      for Y in 1 .. M.Height loop
         Ada.Text_IO.Put
           (File, "    """ & Row_Image (M, Y, Tiles) & """");
         if Y < M.Height then
            Ada.Text_IO.Put_Line (File, ",");
         else
            Ada.Text_IO.New_Line (File);
         end if;
      end loop;
      Ada.Text_IO.Put_Line (File, "  ]");
      Ada.Text_IO.Put_Line (File, "}");
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Write_Map_File;

   procedure Write_Index (Path : String; Version : String) is
      File : Ada.Text_IO.File_Type;
      Seed : RNG.Word;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "{");
      Ada.Text_IO.Put_Line
        (File, "  ""version"": """ & Version & """,");
      Ada.Text_IO.Put_Line (File, "  ""maps"": [");
      for Index in Export_Seeds'Range loop
         Seed := Export_Seeds (Index);
         Ada.Text_IO.Put
           (File,
            "    {""seed"": " & Trim (RNG.Word'Image (Seed))
            & ", ""file"": ""seed-" & Trim (RNG.Word'Image (Seed))
            & ".json""}");
         if Index < Export_Seeds'Last then
            Ada.Text_IO.Put_Line (File, ",");
         else
            Ada.Text_IO.New_Line (File);
         end if;
      end loop;
      Ada.Text_IO.Put_Line (File, "  ]");
      Ada.Text_IO.Put_Line (File, "}");
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Write_Index;

   function Bare_Directory (Directory : String) return String is
   begin
      if Directory'Length > 1
        and then Directory (Directory'Last) = '/'
      then
         return Directory (Directory'First .. Directory'Last - 1);
      end if;
      return Directory;
   end Bare_Directory;

   function Parent_Directory (Path : String) return String is
      Bare : constant String := Bare_Directory (Path);
      Last : Natural := Bare'Last;
   begin
      while Last >= Bare'First and then Bare (Last) /= '/' loop
         Last := Last - 1;
      end loop;
      if Last > Bare'First then
         return Bare (Bare'First .. Last - 1);
      end if;
      return ".";
   end Parent_Directory;

   procedure Export_Maps (Directory : String; Version : String) is
      Folder : constant String := Bare_Directory (Directory);
      Store  : constant Disk.Disk :=
        Disk.Open (Parent_Directory (Folder));
      Tiles  : constant Placeholder.Tileset :=
        Placeholder.Load (Store);
   begin
      Ada.Directories.Create_Path (Folder);
      for Index in Export_Seeds'Range loop
         declare
            M : constant City :=
              Test_Layout (Export_Seeds (Index), Parameters.Defaults);
         begin
            Write_Map_File
              (Folder & "/seed-"
               & Trim (RNG.Word'Image (Export_Seeds (Index)))
               & ".json",
               Version,
               M,
               Tiles);
         end;
      end loop;
      Write_Index (Folder & "/index.json", Version);
   end Export_Maps;

end Megacorp.Map;
