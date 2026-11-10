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

with Megacorp.Data.Virtual_FS;
with Megacorp.Map;

--  Item 4. Placeholder tileset. Tile ids come from assets/tiles.json
--  read through Virtual_FS. Id is Terrain'Pos * 16 + height.
package Megacorp.Assets.Placeholder is
   package Files renames Megacorp.Data.Virtual_FS;

   type Tileset is private;

   function Load
     (Store : Files.Backend'Class) return Tileset
     with Pre => Files.Exists (Store, "assets/tiles.json"),
       Post => Complete (Load'Result);

   function Complete (Set : Tileset) return Boolean;

   function Has_Tile
     (Set : Tileset;
      Kind : Map.Terrain;
      Level : Map.Height_Level) return Boolean;

   function Tile_Id
     (Set : Tileset;
      Kind : Map.Terrain;
      Level : Map.Height_Level) return Natural
     with Pre => Has_Tile (Set, Kind, Level),
       Post =>
         Tile_Id'Result = Map.Terrain'Pos (Kind) * 16 + Level;

private
   type Id_Table is array (Map.Terrain, Map.Height_Level) of Natural;
   type Seen_Table is array (Map.Terrain, Map.Height_Level) of Boolean;

   type Tileset is record
      Ids  : Id_Table := (others => (others => 0));
      Seen : Seen_Table := (others => (others => False));
   end record;
end Megacorp.Assets.Placeholder;
