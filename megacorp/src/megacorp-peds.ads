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

with Ada.Containers.Vectors;
with Megacorp.Map;
use type Ada.Containers.Count_Type;
use type Megacorp.Map.Point;

--  Item 6. One ped on a Megacorp.Path route, advanced by a fixed tick.
--  The position inside a tile is an integer count of sub-tile steps
--  (Along, 0 at the tile centre, toward the next route tile). Facing
--  is the eight-way direction of travel. Speed is sub-tile steps per
--  tick. There is no floating point.
--  Peds occupy their current tile, and also the next tile once a
--  crossing has started. A ped whose next tile is taken waits. After
--  Wait_Limit ticks the ped with the greater id repaths once, treating
--  the other peds' tiles as blocked for that search. The lower id
--  keeps its route. Ticks run in ascending id order, so two peds cannot
--  both enter one free tile on the same tick.
package Megacorp.Peds is
   Steps_Per_Tile : constant := 8;
   Default_Speed  : constant Positive := 1;
   Wait_Limit     : constant := 3;

   subtype Ped_Id is Positive range 1 .. 8;

   type State_Kind is (Standing, Walking, Arrived);

   type Ped is private;

   type Crowd is array (Positive range <>) of Ped;

   function Spawn
     (Who : Ped_Id;
      Start, Goal : Map.Point;
      M : Map.City;
      Speed : Positive := Default_Speed) return Ped
     with Pre =>
       Map.In_Bounds (M, Start.X, Start.Y)
       and then Map.In_Bounds (M, Goal.X, Goal.Y)
       and then Map.Tile_At (M, Start.X, Start.Y).Walkable
       and then Map.Tile_At (M, Goal.X, Goal.Y).Walkable
       and then Speed <= Steps_Per_Tile;

   function Ident (P : Ped) return Ped_Id;
   function Tile_X (P : Ped) return Positive;
   function Tile_Y (P : Ped) return Positive;
   function Along (P : Ped) return Natural
     with Post => Along'Result < Steps_Per_Tile;
   function Facing (P : Ped) return Map.Eight_Way;
   function State_Of (P : Ped) return State_Kind;
   function Speed_Of (P : Ped) return Positive;

   --  Ticks needed to finish one tile at this speed.
   function Ticks_To_Cross (Speed : Positive) return Positive
     with Pre => Speed <= Steps_Per_Tile,
       Post =>
         Ticks_To_Cross'Result * Speed >= Steps_Per_Tile
         and then (Ticks_To_Cross'Result - 1) * Speed
           < Steps_Per_Tile;

   function Distinct_Ids (Group : Crowd) return Boolean;

   procedure Tick (Group : in out Crowd; M : Map.City)
     with Pre => Distinct_Ids (Group);

   type Frame is record
      Tick   : Natural;
      Ident  : Ped_Id;
      X      : Positive;
      Y      : Positive;
      Along  : Natural;
      Facing : Map.Eight_Way;
      State  : State_Kind;
   end record;

   package Frame_Lists is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Frame);

   --  Tick 0, then each tick until every ped has arrived or
   --  Max_Ticks is reached. One frame per ped per recorded tick,
   --  in crowd order.
   function Run
     (M : Map.City;
      Start : Crowd;
      Max_Ticks : Natural) return Frame_Lists.Vector
     with Pre =>
       Start'Length > 0 and then Distinct_Ids (Start),
       Post => Run'Result.Length >= Start'Length;

private
   package Step_Lists is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Map.Point);

   type Ped is record
      Ident   : Ped_Id := 1;
      X       : Positive := 1;
      Y       : Positive := 1;
      Goal_X  : Positive := 1;
      Goal_Y  : Positive := 1;
      Along   : Natural := 0;
      Facing  : Map.Eight_Way := Map.South;
      Speed   : Positive := Default_Speed;
      State   : State_Kind := Standing;
      Wait    : Natural := 0;
      Cursor  : Positive := 1;
      Route   : Step_Lists.Vector;
   end record
     with Type_Invariant =>
       Ped.Along < Steps_Per_Tile
       and then Ped.Speed <= Steps_Per_Tile
       and then (if Ped.State = Arrived then Ped.Along = 0);
end Megacorp.Peds;
