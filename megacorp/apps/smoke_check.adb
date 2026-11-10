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

package body Smoke_Check is
   Failures : Natural := 0;

   procedure Expect (Condition : Boolean; Name : String) is
   begin
      if Condition then
         Ada.Text_IO.Put_Line ("PASS " & Name);
      else
         Ada.Text_IO.Put_Line ("FAIL " & Name);
         Failures := Failures + 1;
      end if;
   end Expect;

   procedure Discard (Value : Integer) is
      pragma Unreferenced (Value);
   begin
      null;
   end Discard;

   function Failure_Count return Natural is
   begin
      return Failures;
   end Failure_Count;
end Smoke_Check;
