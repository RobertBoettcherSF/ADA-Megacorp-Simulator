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

--  Tiny helper for the 0.1.0 smoke test. Not part of the core.
package Smoke_Check is
   procedure Expect (Condition : Boolean; Name : String)
     with Pre => Name'Length > 0;

   procedure Discard (Value : Integer);

   function Failure_Count return Natural;
end Smoke_Check;
