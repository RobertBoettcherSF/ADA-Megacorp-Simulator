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

with Ada.Real_Time;
with Ada.Text_IO;

package body Megacorp.Host is
   Epoch : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

   procedure Log (Level : Log_Level; Message : String) is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Current_Error,
         "megacorp: " & Level'Image & ": " & Message);
   end Log;

   function Monotonic_Milliseconds return Milliseconds is
      use type Ada.Real_Time.Time;

      Elapsed : constant Duration :=
        Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Epoch);
      Scaled  : constant Duration := Elapsed * 1_000;
   begin
      if Scaled <= 0.0 then
         return 0;
      end if;
      return Milliseconds (Scaled);
   end Monotonic_Milliseconds;

end Megacorp.Host;
