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

with Ada.Assertions;
with Ada.Command_Line;
with Ada.Text_IO;
with Ada.Containers;
with Ada.Strings.Fixed;
with Megacorp.Assets.Placeholder;
with Megacorp.Data.Virtual_FS.Native;
with Megacorp.Host;
with Megacorp.Map;
with Megacorp.Parameters;
with Megacorp.RNG;
with Smoke_Check;

procedure Megacorp_Smoke is
   package Params renames Megacorp.Parameters;
   package RNG renames Megacorp.RNG;
   use type RNG.Word;
   use type Megacorp.Map.City;
   use type Megacorp.Map.Terrain;

   type Sample is array (Positive range <>) of Integer;
   procedure Shuffle_Sample is new RNG.Shuffle
     (Item => Integer, Index => Positive, Collection => Sample);

   Defaults : constant Params.Generator_Parameters := Params.Defaults;
   Custom   : Params.Generator_Parameters;
   Rejected : Params.Generator_Parameters;
   Raised   : Boolean;
   Earlier  : Megacorp.Host.Milliseconds;
   Later    : Megacorp.Host.Milliseconds;
begin
   Smoke_Check.Expect
     (Megacorp.Version = "0.4.0"
      and then Megacorp.Name = "Megacorp Simulator",
      "version 0.4.0");
   Smoke_Check.Expect
     (Params.Corporation_Count (Defaults) = 4
      and then Params.Region_Count (Defaults) = 40
      and then Params.City_Map_Width (Defaults) = 128
      and then Params.City_Map_Height (Defaults) = 128,
      "default parameters");
   Custom := Params.Make (2, 10, 64, 96);
   Smoke_Check.Expect
     (Params.Corporation_Count (Custom) = 2
      and then Params.Region_Count (Custom) = 10
      and then Params.City_Map_Width (Custom) = 64
      and then Params.City_Map_Height (Custom) = 96,
      "parameters are not fixed constants");
   Smoke_Check.Expect
     (not Params.Region_May_Reroll (Params.Scenario, False)
      and then not Params.Region_May_Reroll (Params.Scenario, True)
      and then Params.Region_May_Reroll (Params.Free_Play, False)
      and then Params.Region_May_Reroll (Params.Auto_Play, False)
      and then not Params.Region_May_Reroll (Params.Free_Play, True)
      and then not Params.Region_May_Reroll (Params.Auto_Play, True),
      "re-roll rule");

   Raised := False;
   begin
      Rejected :=
        Params.Make
          (0,
           Params.Default_Regions,
           Params.Default_City_Map_Width,
           Params.Default_City_Map_Height);
      Smoke_Check.Discard (Params.Corporation_Count (Rejected));
   exception
      when Ada.Assertions.Assertion_Error =>
         Raised := True;
   end;
   Smoke_Check.Expect (Raised, "make rejects 0 corporations");

   Raised := False;
   begin
      Rejected :=
        Params.Make
          (Params.Default_Corporations,
           Params.Default_Regions,
           Params.Max_City_Map_Edge + 1,
           Params.Default_City_Map_Height);
      Smoke_Check.Discard (Params.City_Map_Width (Rejected));
   exception
      when Ada.Assertions.Assertion_Error =>
         Raised := True;
   end;
   Smoke_Check.Expect (Raised, "make rejects an oversized map");

   Earlier := Megacorp.Host.Monotonic_Milliseconds;
   delay 0.01;
   Later := Megacorp.Host.Monotonic_Milliseconds;
   Smoke_Check.Expect (Later >= Earlier, "clock does not go backwards");

   Megacorp.Host.Log (Megacorp.Host.Info, "smoke");
   Smoke_Check.Expect (True, "log accepts a message");

   Raised := False;
   begin
      Megacorp.Host.Log (Megacorp.Host.Info, "");
   exception
      when Ada.Assertions.Assertion_Error =>
         Raised := True;
   end;
   Smoke_Check.Expect (Raised, "log rejects an empty message");

   declare
      Published : RNG.Generator := RNG.Restore (0, 1, 2, 3, 4);
      Seeded    : RNG.Generator := RNG.Make (0);
      Left      : RNG.Generator := RNG.Make (99);
      Right     : RNG.Generator := RNG.Make (99);
      Other     : RNG.Generator := RNG.Make (100);
      World     : RNG.Generator := RNG.Make (42);
      Region_1  : RNG.Generator :=
        RNG.Child (World, RNG.Region, 1);
      Region_2  : RNG.Generator :=
        RNG.Child (World, RNG.Region, 2);
      City_1    : RNG.Generator :=
        RNG.Child (World, RNG.City, 1);
      Again     : RNG.Generator;
      Again_2   : RNG.Generator;
      Bounds    : RNG.Generator := RNG.Make (7);
      Deck      : Sample (1 .. 5) := (1, 2, 3, 4, 5);
      Seen      : array (1 .. 5) of Boolean := (others => False);
      Same      : Boolean;
      In_Bounds : Boolean := True;
      Shuffled  : Boolean := True;
      First_L   : RNG.Word;
      First_R   : RNG.Word;
      First_O   : RNG.Word;
      First_R1  : RNG.Word;
      First_R2  : RNG.Word;
      First_C1  : RNG.Word;
      Drawn     : Long_Long_Integer;
      Picked    : Integer;
      Remaining : Natural;
   begin
      Smoke_Check.Expect
        (RNG.Next (Published) = 16#0000_0000_0000_2D00#
         and then RNG.Next (Published) = 0
         and then RNG.Next (Published) = 16#0000_0000_5A00_7080#
         and then RNG.Next (Published) = 16#10E0_0000_0000_9D80#,
         "xoshiro256** reference vector");
      Smoke_Check.Expect
        (RNG.State_Word (Seeded, 1) = 16#E220_A839_7B1D_CDAF#
         and then RNG.State_Word (Seeded, 2) = 16#6E78_9E6A_A1B9_65F4#
         and then RNG.State_Word (Seeded, 3) = 16#06C4_5D18_8009_454F#
         and then RNG.State_Word (Seeded, 4) = 16#F88B_B8A8_724C_81EC#
         and then RNG.Next (Seeded) = 16#99EC_5F36_CB75_F2B4#
         and then RNG.Next (Seeded) = 16#BF6E_1F78_4956_452A#
         and then RNG.Next (Seeded) = 16#1A5F_849D_4933_E6E0#
         and then RNG.Next (Seeded) = 16#6AA5_94F1_262D_2D2C#,
         "Make(0) reference vector");

      First_L := RNG.Next (Left);
      First_R := RNG.Next (Right);
      First_O := RNG.Next (Other);
      Same := First_L = First_R and then First_O /= First_L;
      Remaining := 3;
      while Remaining > 0 loop
         Same := Same and then RNG.Next (Left) = RNG.Next (Right);
         Remaining := Remaining - 1;
      end loop;
      Smoke_Check.Expect (Same, "same seed gives the same sequence");

      First_R1 := RNG.Next (Region_1);
      First_R2 := RNG.Next (Region_2);
      First_C1 := RNG.Next (City_1);
      Smoke_Check.Discard (Integer (RNG.Next (World) mod 16));
      Smoke_Check.Discard (Integer (RNG.Next (Region_2) mod 16));
      Again := RNG.Child (World, RNG.Region, 1);
      Again_2 := RNG.Child (World, RNG.Region, 2);
      Smoke_Check.Expect
        (RNG.Next (Again) = First_R1
         and then RNG.Next (Again_2) = First_R2
         and then First_R1 /= First_R2
         and then First_R1 /= First_C1
         and then First_R2 /= First_C1,
         "child streams stay independent");

      Remaining := 16;
      while Remaining > 0 loop
         Picked := RNG.Pick (Bounds, -3, 5);
         Drawn := RNG.Uniform (Bounds, -20, 20);
         In_Bounds :=
           In_Bounds
           and then Picked in -3 .. 5
           and then Drawn in -20 .. 20
           and then RNG.Pick (Bounds, 0, 7) in 0 .. 7;
         Remaining := Remaining - 1;
      end loop;
      Smoke_Check.Expect
        (In_Bounds
         and then not RNG.Chance (Bounds, 0, 4)
         and then RNG.Chance (Bounds, 4, 4),
         "ranges stay in bounds");

      Shuffle_Sample (Bounds, Deck);
      for Value of Deck loop
         if Value in 1 .. 5 then
            Seen (Value) := True;
         else
            Shuffled := False;
         end if;
      end loop;
      Smoke_Check.Expect
        (Shuffled
         and then Seen (1) and then Seen (2) and then Seen (3)
         and then Seen (4) and then Seen (5),
         "shuffle keeps every value");
   end;

   declare
      package Map renames Megacorp.Map;

      Small   : constant Map.City := Map.Test_Layout (1, 5, 5);
      Layout  : constant Map.City := Map.Test_Layout (42, 24, 24);
      Repeat  : constant Map.City := Map.Test_Layout (42, 24, 24);
      Other   : constant Map.City := Map.Test_Layout (99, 24, 24);
      Full    : constant Map.City :=
        Map.Test_Layout (42, Defaults);
      Here    : Map.Point;
      Cell    : Map.Tile;
      Seen_Water    : Boolean := False;
      Seen_Road     : Boolean := False;
      Seen_Building : Boolean := False;
      Rules         : Boolean := True;
   begin
      Raised := False;
      begin
         if Map.Tile_At (Small, 0, 1).Kind = Map.Water then
            Raised := False;
         end if;
      exception
         when Ada.Assertions.Assertion_Error =>
            Raised := True;
      end;
      Smoke_Check.Expect
        (Raised
         and then Small.Width = 5
         and then Map.Tile_At (Small, 1, 1).Kind = Map.Open_Ground,
         "map bounds");

      Here := Map.Neighbour_4 (Small, 3, 3, Map.North);
      Smoke_Check.Expect
        (not Map.Has_Neighbour_4 (Small, 1, 1, Map.North)
         and then not Map.Has_Neighbour_4 (Small, 1, 1, Map.West)
         and then Map.Neighbour_4 (Small, 1, 1, Map.East).X = 2
         and then Map.Neighbour_4 (Small, 1, 1, Map.East).Y = 1
         and then Map.Neighbour_4 (Small, 1, 1, Map.South).Y = 2
         and then Here.X = 3
         and then Here.Y = 2
         and then Map.Has_Neighbour_8 (Small, 3, 3, Map.South_East)
         and then Map.Neighbour_8 (Small, 3, 3, Map.South_East).X = 4
         and then Map.Neighbour_8 (Small, 3, 3, Map.South_East).Y = 4
         and then not Map.Has_Neighbour_8 (Small, 1, 1, Map.North_West),
         "map neighbours");

      for Y in 1 .. Layout.Height loop
         for X in 1 .. Layout.Width loop
            Cell := Map.Tile_At (Layout, X, Y);
            case Cell.Kind is
               when Map.Water =>
                  Seen_Water := True;
                  Rules := Rules
                    and then not Cell.Walkable
                    and then not Cell.Drivable
                    and then Cell.Level = 0;
               when Map.Road =>
                  Seen_Road := True;
                  Rules := Rules
                    and then Cell.Walkable
                    and then Cell.Drivable;
               when Map.Building =>
                  Seen_Building := True;
                  Rules := Rules
                    and then not Cell.Walkable
                    and then not Cell.Drivable;
               when Map.Open_Ground | Map.Pavement =>
                  Rules := Rules
                    and then Cell.Walkable
                    and then not Cell.Drivable;
            end case;
         end loop;
      end loop;
      Smoke_Check.Expect
        (Rules and then Seen_Water and then Seen_Road
         and then Seen_Building,
         "test layout walkability");
      Smoke_Check.Expect
        (Layout = Repeat
         and then Layout /= Other
         and then Full.Width = 128
         and then Full.Height = 128
         and then Map.Layout_Seed (Full) = 42,
         "test layout follows the seed");
   end;

   declare
      package Native renames Megacorp.Data.Virtual_FS.Native;
      package Tiles renames Megacorp.Assets.Placeholder;
      use type Ada.Containers.Count_Type;

      Store : constant Native.Disk := Native.Open ("../web");
      Names : constant Megacorp.Data.Virtual_FS.Name_Lists.Vector :=
        Native.List (Store, "assets");
      Text  : constant String :=
        Native.Read (Store, "assets/tiles.json");
      Set   : constant Tiles.Tileset := Tiles.Load (Store);
      Listed_Index : Boolean := False;
      Listed_Atlas : Boolean := False;
      Ids_Ok : Boolean := True;
   begin
      if Names.Length > 0 then
         for I in 1 .. Positive (Names.Length) loop
            if Names.Element (I) = "tiles.json" then
               Listed_Index := True;
            elsif Names.Element (I) = "atlas.png" then
               Listed_Atlas := True;
            end if;
         end loop;
      end if;
      Smoke_Check.Expect
        (Native.Exists (Store, "assets/tiles.json")
         and then Ada.Strings.Fixed.Index (Text, """tile_width""") > 0
         and then Listed_Index
         and then Listed_Atlas
         and then not Native.Exists (Store, "assets/missing.txt")
         and then not Native.Exists (Store, "../secret"),
         "virtual file system");
      Raised := False;
      begin
         declare
            Ignored : constant String :=
              Native.Read (Store, "assets/missing.txt");
         begin
            Smoke_Check.Discard (Ignored'Length);
         end;
      exception
         when Ada.Assertions.Assertion_Error =>
            Raised := True;
      end;
      Smoke_Check.Expect (Raised, "missing file is not readable");
      for Kind in Megacorp.Map.Terrain loop
         for Level in Megacorp.Map.Height_Level loop
            Ids_Ok := Ids_Ok
              and then Tiles.Tile_Id (Set, Kind, Level)
                = Megacorp.Map.Terrain'Pos (Kind) * 16 + Level;
         end loop;
      end loop;
      Smoke_Check.Expect
        (Tiles.Complete (Set) and then Ids_Ok,
         "placeholder tile index");
   end;

   if Smoke_Check.Failure_Count = 0 then
      Ada.Text_IO.Put_Line ("smoke: PASS");
   else
      Ada.Text_IO.Put_Line ("smoke: FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Megacorp_Smoke;
