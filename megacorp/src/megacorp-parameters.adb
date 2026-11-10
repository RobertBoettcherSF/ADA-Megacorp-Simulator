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

package body Megacorp.Parameters is

   function Valid (P : Generator_Parameters) return Boolean is
     (P.Corporations in Min_Corporations .. Max_Corporations
      and then P.Regions in Min_Regions .. Max_Regions
      and then P.Map_Width in Min_City_Map_Edge .. Max_City_Map_Edge
      and then P.Map_Height in Min_City_Map_Edge .. Max_City_Map_Edge);

   function Defaults return Generator_Parameters is
   begin
      return
        (Corporations => Default_Corporations,
         Regions      => Default_Regions,
         Map_Width    => Default_City_Map_Width,
         Map_Height   => Default_City_Map_Height);
   end Defaults;

   function Make
     (Corporations : Integer;
      Regions      : Integer;
      Map_Width    : Integer;
      Map_Height   : Integer) return Generator_Parameters
   is
      Result : Generator_Parameters;
   begin
      Result.Corporations := Corporations;
      Result.Regions := Regions;
      Result.Map_Width := Map_Width;
      Result.Map_Height := Map_Height;
      pragma Assert
        (Result.Corporations = Corporations
         and then Result.Regions = Regions
         and then Result.Map_Width = Map_Width
         and then Result.Map_Height = Map_Height);
      return Result;
   end Make;

   function Corporation_Count
     (P : Generator_Parameters) return Positive
   is
   begin
      return P.Corporations;
   end Corporation_Count;

   function Region_Count (P : Generator_Parameters) return Positive is
   begin
      return P.Regions;
   end Region_Count;

   function City_Map_Width (P : Generator_Parameters) return Positive is
   begin
      return P.Map_Width;
   end City_Map_Width;

   function City_Map_Height (P : Generator_Parameters) return Positive is
   begin
      return P.Map_Height;
   end City_Map_Height;

   function Unvisited_Regions_May_Reroll
     (Mode : Play_Mode) return Boolean
   is
   begin
      return Mode /= Scenario;
   end Unvisited_Regions_May_Reroll;

   function Region_May_Reroll
     (Mode : Play_Mode; Visited : Boolean) return Boolean
   is
   begin
      return not Visited and then Unvisited_Regions_May_Reroll (Mode);
   end Region_May_Reroll;

end Megacorp.Parameters;
