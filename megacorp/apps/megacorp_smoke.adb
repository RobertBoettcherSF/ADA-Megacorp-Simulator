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
with Megacorp.Host;
with Megacorp.Parameters;
with Smoke_Check;

procedure Megacorp_Smoke is
   package Params renames Megacorp.Parameters;

   Defaults : constant Params.Generator_Parameters := Params.Defaults;
   Custom   : Params.Generator_Parameters;
   Rejected : Params.Generator_Parameters;
   Raised   : Boolean;
   Earlier  : Megacorp.Host.Milliseconds;
   Later    : Megacorp.Host.Milliseconds;
begin
   Smoke_Check.Expect
     (Megacorp.Version = "0.1.0"
      and then Megacorp.Name = "Megacorp Simulator",
      "version 0.1.0");
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

   if Smoke_Check.Failure_Count = 0 then
      Ada.Text_IO.Put_Line ("smoke: PASS");
   else
      Ada.Text_IO.Put_Line ("smoke: FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Megacorp_Smoke;
