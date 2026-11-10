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

--  Host services for item 1: a monotonic clock and a log.
--  Filesystem and browser storage hooks arrive with the virtual
--  filesystem (item 4) and browser storage (item 21). This package
--  does not talk to SDL, the DOM, or a socket.
package Megacorp.Host is
   type Log_Level is (Debug, Info, Warning, Error);

   procedure Log (Level : Log_Level; Message : String)
     with Pre => Message'Length > 0;

   subtype Milliseconds is Long_Long_Integer range 0 .. Long_Long_Integer'Last;

   --  Milliseconds since this process first read the monotonic clock.
   --  Does not go backwards during one run. Not a wall clock.
   function Monotonic_Milliseconds return Milliseconds;
end Megacorp.Host;
