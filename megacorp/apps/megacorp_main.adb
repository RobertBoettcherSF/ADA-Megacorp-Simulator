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

with Ada.Text_IO;
with Megacorp.Host;
with Megacorp.Parameters;

procedure Megacorp_Main is
   package Params renames Megacorp.Parameters;

   P : constant Params.Generator_Parameters := Params.Defaults;

   Visited_Stays : constant Boolean :=
     not Params.Region_May_Reroll (Params.Scenario, True)
     and then not Params.Region_May_Reroll (Params.Free_Play, True)
     and then not Params.Region_May_Reroll (Params.Auto_Play, True);
begin
   Megacorp.Host.Log (Megacorp.Host.Info, "start " & Megacorp.Version);
   Ada.Text_IO.Put_Line (Megacorp.Name & " " & Megacorp.Version);
   Ada.Text_IO.Put_Line
     ("corporations:" & Params.Corporation_Count (P)'Image);
   Ada.Text_IO.Put_Line ("regions:" & Params.Region_Count (P)'Image);
   Ada.Text_IO.Put_Line
     ("city map:"
      & Params.City_Map_Width (P)'Image
      & " x"
      & Params.City_Map_Height (P)'Image);
   Ada.Text_IO.Put ("scenario: ");
   if Params.Unvisited_Regions_May_Reroll (Params.Scenario) then
      Ada.Text_IO.Put_Line ("unvisited regions may be re-rolled");
   else
      Ada.Text_IO.Put_Line ("locked once generated");
   end if;
   Ada.Text_IO.Put ("free play: ");
   if Params.Unvisited_Regions_May_Reroll (Params.Free_Play) then
      Ada.Text_IO.Put_Line ("unvisited regions may be re-rolled");
   else
      Ada.Text_IO.Put_Line ("locked once generated");
   end if;
   Ada.Text_IO.Put ("auto-play: ");
   if Params.Unvisited_Regions_May_Reroll (Params.Auto_Play) then
      Ada.Text_IO.Put_Line ("unvisited regions may be re-rolled");
   else
      Ada.Text_IO.Put_Line ("locked once generated");
   end if;
   if Visited_Stays then
      Ada.Text_IO.Put_Line ("visited regions stay as left");
   end if;
end Megacorp_Main;
