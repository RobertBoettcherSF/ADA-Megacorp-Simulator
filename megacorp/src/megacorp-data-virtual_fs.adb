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

package body Megacorp.Data.Virtual_FS is

   function Is_Logical_Path (Path : String) return Boolean is
      I         : Natural := Path'First;
      Seg_Start : Natural;
   begin
      if Path'Length = 0 then
         return True;
      end if;
      if Path (Path'First) = '/' or else Path (Path'Last) = '/' then
         return False;
      end if;
      while I <= Path'Last loop
         Seg_Start := I;
         while I <= Path'Last and then Path (I) /= '/' loop
            if Path (I) = '\' or else Path (I) = Character'Val (0) then
               return False;
            end if;
            I := I + 1;
         end loop;
         if I = Seg_Start then
            return False;
         end if;
         if Path (Seg_Start .. I - 1) = ".."
           or else Path (Seg_Start .. I - 1) = "."
         then
            return False;
         end if;
         if I <= Path'Last and then Path (I) = '/' then
            I := I + 1;
            if I > Path'Last then
               return False;
            end if;
         end if;
      end loop;
      return True;
   end Is_Logical_Path;

end Megacorp.Data.Virtual_FS;
