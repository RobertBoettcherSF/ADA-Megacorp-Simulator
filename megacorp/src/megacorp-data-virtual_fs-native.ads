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

--  Disk backend. Logical paths are relative to Root. This is the
--  only unit that calls the host file system for asset reads.
package Megacorp.Data.Virtual_FS.Native is
   type Disk (Length : Natural) is new Backend with private;

   function Open (Root : String) return Disk
     with Pre => Root'Length > 0,
       Post => Open'Result.Length = Root'Length;

   overriding function Exists
     (Store : Disk; Path : String) return Boolean;

   overriding function Read
     (Store : Disk; Path : String) return String
     with Pre => Exists (Store, Path);

   overriding function List
     (Store : Disk; Path : String) return Name_Lists.Vector
     with Pre => Is_Logical_Path (Path);

private
   type Disk (Length : Natural) is new Backend with record
      Root : String (1 .. Length);
   end record;
end Megacorp.Data.Virtual_FS.Native;
