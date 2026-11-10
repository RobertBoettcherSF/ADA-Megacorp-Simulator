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

package body Megacorp.Actions is
   use type Peds.State_Kind;

   function Trim (Image : String) return String;
   function Facing_Token (Dir : Map.Eight_Way) return String;
   function Find_Actor (Group : Cast; Who : Peds.Ped_Id) return Natural;
   function Find_Item (Items : Bag; Id : Item_Id) return Natural;
   function Close (P : Peds.Ped; Goal : Map.Point) return Boolean;
   procedure Drop_Front (A : in out Actor);
   procedure Clear_Queue (A : in out Actor);
   procedure Apply_Pending (A : in out Actor);
   procedure Prepare
     (Group : in out Cast;
      Index : Positive;
      Bodies : in out Peds.Crowd;
      M : Map.City);
   procedure Resolve
     (Group : in out Cast;
      Index : Positive;
      Items : in out Bag);
   procedure Remember (A : in out Actor; Had : Boolean; Old : Natural);
   function Any_Here (Items : Bag) return Boolean;
   function Idle (Group : Cast) return Boolean;
   procedure Append_Shots
     (Trace : in out Shot_Lists.Vector;
      Group : Cast;
      Items : Bag;
      At_Tick : Natural);

   function Trim (Image : String) return String is
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;
      return Image;
   end Trim;

   function Facing_Token (Dir : Map.Eight_Way) return String is
   begin
      case Dir is
         when Map.North =>
            return "north";
         when Map.East =>
            return "east";
         when Map.South =>
            return "south";
         when Map.West =>
            return "west";
         when Map.North_East =>
            return "north_east";
         when Map.South_East =>
            return "south_east";
         when Map.South_West =>
            return "south_west";
         when Map.North_West =>
            return "north_west";
      end case;
   end Facing_Token;

   function Make_Walk (Goal : Map.Point) return Action is
   begin
      return (Which => Walk_To, Goal => Goal);
   end Make_Walk;

   function Make_Wait (Ticks : Positive) return Action is
   begin
      return (Which => Wait, Total => Ticks, Left => Ticks);
   end Make_Wait;

   function Make_Turn (Dir : Map.Eight_Way) return Action is
   begin
      return (Which => Turn_To, Dir => Dir);
   end Make_Turn;

   function Make_Follow (Target : Peds.Ped_Id) return Action is
   begin
      return (Which => Follow, Target => Target);
   end Make_Follow;

   function Make_Pick (Item : Item_Id) return Action is
   begin
      return (Which => Pick_Up, Item => Item);
   end Make_Pick;

   function Token (A : Action) return String is
   begin
      case A.Which is
         when Walk_To =>
            return "walk_to "
              & Trim (Integer'Image (A.Goal.X)) & ","
              & Trim (Integer'Image (A.Goal.Y));
         when Wait =>
            return "wait " & Trim (Integer'Image (A.Total));
         when Turn_To =>
            return "turn_to " & Facing_Token (A.Dir);
         when Follow =>
            return "follow "
              & Trim (Integer'Image (Integer (A.Target)));
         when Pick_Up =>
            return "pick_up "
              & Trim (Integer'Image (Integer (A.Item)));
      end case;
   end Token;

   function Recruit
     (Who : Peds.Ped_Id;
      At_Point : Map.Point;
      M : Map.City) return Actor
   is
      A : Actor;
   begin
      A.Walker := Peds.Place (Who, At_Point, M);
      return A;
   end Recruit;

   function Length (A : Actor) return Natural is
   begin
      return A.Live_Count;
   end Length;

   function Is_Pending (A : Actor) return Boolean is
   begin
      return A.Has_Pending;
   end Is_Pending;

   function Room (A : Actor; How : Mode) return Natural is
      Used : Natural;
   begin
      if How = Replace then
         return Capacity;
      end if;
      Used := A.Live_Count;
      if A.Has_Pending and then A.Pending_Mode = Append then
         Used := Used + A.Pending_Count;
      end if;
      if Used >= Capacity then
         return 0;
      end if;
      return Capacity - Used;
   end Room;

   function Front (A : Actor) return Action is
   begin
      return A.Live (1);
   end Front;

   function At_Queue (A : Actor; Index : Positive) return Action is
   begin
      return A.Live (Index);
   end At_Queue;

   function Ped_Ident (A : Actor) return Peds.Ped_Id is
   begin
      return Peds.Ident (A.Walker);
   end Ped_Ident;

   function Ped_X (A : Actor) return Positive is
   begin
      return Peds.Tile_X (A.Walker);
   end Ped_X;

   function Ped_Y (A : Actor) return Positive is
   begin
      return Peds.Tile_Y (A.Walker);
   end Ped_Y;

   function Ped_Along (A : Actor) return Natural is
   begin
      return Peds.Along (A.Walker);
   end Ped_Along;

   function Ped_Facing (A : Actor) return Map.Eight_Way is
   begin
      return Peds.Facing (A.Walker);
   end Ped_Facing;

   function Ped_State (A : Actor) return Peds.State_Kind is
   begin
      return Peds.State_Of (A.Walker);
   end Ped_State;

   function Distinct (Group : Cast) return Boolean is
   begin
      for I in Group'Range loop
         for J in Group'Range loop
            if I /= J
              and then Peds.Ident (Group (I).Walker)
                = Peds.Ident (Group (J).Walker)
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Distinct;

   function Find_Actor (Group : Cast; Who : Peds.Ped_Id) return Natural is
   begin
      for I in Group'Range loop
         if Peds.Ident (Group (I).Walker) = Who then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Actor;

   function Find_Item (Items : Bag; Id : Item_Id) return Natural is
   begin
      for I in Items'Range loop
         if Items (I).Ident = Id then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Item;

   function Close (P : Peds.Ped; Goal : Map.Point) return Boolean is
   begin
      return abs (Peds.Tile_X (P) - Goal.X) <= 1
        and then abs (Peds.Tile_Y (P) - Goal.Y) <= 1;
   end Close;

   procedure Drop_Front (A : in out Actor) is
   begin
      if A.Live_Count = 0 then
         return;
      end if;
      for I in 1 .. A.Live_Count - 1 loop
         A.Live (I) := A.Live (I + 1);
      end loop;
      A.Live_Count := A.Live_Count - 1;
      A.Commanded := False;
      A.Settled := False;
   end Drop_Front;

   procedure Clear_Queue (A : in out Actor) is
   begin
      A.Live_Count := 0;
      A.Pending_Count := 0;
      A.Has_Pending := False;
      A.Commanded := False;
      A.Settled := False;
      A.Failed := False;
      Peds.Halt (A.Walker);
   end Clear_Queue;

   procedure Apply_Pending (A : in out Actor) is
   begin
      if not A.Has_Pending then
         return;
      end if;
      if A.Pending_Mode = Replace then
         A.Live_Count := 0;
         A.Commanded := False;
         A.Settled := False;
         Peds.Halt (A.Walker);
      end if;
      for I in 1 .. A.Pending_Count loop
         A.Live_Count := A.Live_Count + 1;
         A.Live (A.Live_Count) := A.Pending (I);
      end loop;
      A.Has_Pending := False;
      A.Pending_Count := 0;
   end Apply_Pending;

   procedure Order
     (Group : in out Cast;
      Index : Positive;
      Actions : Action_Array;
      How : Mode)
   is
   begin
      if How = Append
        and then Group (Index).Has_Pending
        and then Group (Index).Pending_Mode = Append
      then
         for I in Actions'Range loop
            Group (Index).Pending_Count :=
              Group (Index).Pending_Count + 1;
            Group (Index).Pending (Group (Index).Pending_Count) :=
              Actions (I);
         end loop;
         return;
      end if;
      Group (Index).Pending_Count := 0;
      for I in Actions'Range loop
         Group (Index).Pending_Count := Group (Index).Pending_Count + 1;
         Group (Index).Pending (Group (Index).Pending_Count) :=
           Actions (I);
      end loop;
      Group (Index).Pending_Mode := How;
      Group (Index).Has_Pending := Group (Index).Pending_Count > 0;
   end Order;

   procedure Prepare
     (Group : in out Cast;
      Index : Positive;
      Bodies : in out Peds.Crowd;
      M : Map.City)
   is
      Accepted : Boolean;
      Leader   : Natural;
      Goal     : Map.Point;
   begin
      Group (Index).Failed := False;
      Group (Index).Settled := False;
      if Group (Index).Live_Count = 0 then
         return;
      end if;
      case Group (Index).Live (1).Which is
         when Walk_To =>
            if not Group (Index).Commanded then
               Peds.Command_Walk
                 (Bodies, Index, Group (Index).Live (1).Goal,
                  M, Accepted);
               if not Accepted then
                  Group (Index).Failed := True;
               else
                  Group (Index).Commanded := True;
               end if;
            end if;
         when Follow =>
            Leader := Find_Actor
              (Group, Group (Index).Live (1).Target);
            if Leader = 0 then
               Group (Index).Failed := True;
            elsif Peds.Along (Bodies (Index)) = 0 then
               Goal :=
                 (X => Peds.Tile_X (Bodies (Leader)),
                  Y => Peds.Tile_Y (Bodies (Leader)));
               if Close (Bodies (Index), Goal)
                 and then Peds.State_Of (Bodies (Leader)) = Peds.Arrived
               then
                  Peds.Halt (Bodies (Index));
                  Group (Index).Settled := True;
               elsif not Group (Index).Commanded
                 or else Goal.X /= Group (Index).Command_X
                 or else Goal.Y /= Group (Index).Command_Y
               then
                  Peds.Command_Walk
                    (Bodies, Index, Goal, M, Accepted);
                  if not Accepted then
                     if not Close (Bodies (Index), Goal) then
                        Group (Index).Failed := True;
                     end if;
                  else
                     Group (Index).Commanded := True;
                     Group (Index).Command_X := Goal.X;
                     Group (Index).Command_Y := Goal.Y;
                  end if;
               end if;
            end if;
         when Wait | Turn_To | Pick_Up =>
            null;
      end case;
   end Prepare;

   procedure Resolve
     (Group : in out Cast;
      Index : Positive;
      Items : in out Bag)
   is
      Slot : Natural;
   begin
      if Group (Index).Live_Count = 0 then
         return;
      end if;
      if Group (Index).Failed then
         Clear_Queue (Group (Index));
         return;
      end if;
      case Group (Index).Live (1).Which is
         when Walk_To =>
            if Peds.State_Of (Group (Index).Walker) = Peds.Arrived
              and then Peds.Tile_X (Group (Index).Walker)
                = Group (Index).Live (1).Goal.X
              and then Peds.Tile_Y (Group (Index).Walker)
                = Group (Index).Live (1).Goal.Y
            then
               Drop_Front (Group (Index));
            end if;
         when Wait =>
            if Group (Index).Live (1).Left > 0 then
               Group (Index).Live (1).Left :=
                 Group (Index).Live (1).Left - 1;
            end if;
            if Group (Index).Live (1).Left = 0 then
               Drop_Front (Group (Index));
            end if;
         when Turn_To =>
            Peds.Set_Facing
              (Group (Index).Walker, Group (Index).Live (1).Dir);
            Drop_Front (Group (Index));
         when Follow =>
            if Group (Index).Settled then
               Drop_Front (Group (Index));
            end if;
         when Pick_Up =>
            Slot := Find_Item (Items, Group (Index).Live (1).Item);
            if Slot = 0
              or else not Items (Slot).Here
              or else Items (Slot).X /= Peds.Tile_X (Group (Index).Walker)
              or else Items (Slot).Y /= Peds.Tile_Y (Group (Index).Walker)
              or else Peds.Along (Group (Index).Walker) /= 0
            then
               Clear_Queue (Group (Index));
            else
               Items (Slot).Here := False;
               Drop_Front (Group (Index));
            end if;
      end case;
   end Resolve;

   procedure Remember (A : in out Actor; Had : Boolean; Old : Natural) is
   begin
      if not Had then
         A.Has_Action := False;
         A.Rest_Count := 0;
         return;
      end if;
      A.Has_Action := True;
      if A.Live_Count = 0 or else A.Live_Count < Old then
         if A.Live_Count = 0 then
            A.Rest_Count := 0;
         else
            A.Rest_Count := A.Live_Count;
            for I in 1 .. A.Live_Count loop
               A.Rest (I) := Token_Strings.To_Bounded_String
                 (Token (A.Live (I)));
            end loop;
         end if;
      else
         A.Rest_Count := A.Live_Count - 1;
         for I in 1 .. A.Rest_Count loop
            A.Rest (I) := Token_Strings.To_Bounded_String
              (Token (A.Live (I + 1)));
         end loop;
      end if;
   end Remember;

   procedure Tick
     (Group : in out Cast;
      M : Map.City;
      Items : in out Bag)
   is
      Bodies : Peds.Crowd (Group'Range);
      Had    : Boolean;
      Old    : Natural;
   begin
      for I in Group'Range loop
         Apply_Pending (Group (I));
         Bodies (I) := Group (I).Walker;
      end loop;
      for I in Group'Range loop
         Prepare (Group, I, Bodies, M);
      end loop;
      Peds.Tick (Bodies, M);
      for I in Group'Range loop
         Group (I).Walker := Bodies (I);
         Had := Group (I).Live_Count > 0;
         Old := Group (I).Live_Count;
         if Had then
            Group (I).Action := Token_Strings.To_Bounded_String
              (Token (Group (I).Live (1)));
         end if;
         Resolve (Group, I, Items);
         Remember (Group (I), Had, Old);
      end loop;
   end Tick;

   function Any_Here (Items : Bag) return Boolean is
   begin
      for I in Items'Range loop
         if Items (I).Here then
            return True;
         end if;
      end loop;
      return False;
   end Any_Here;

   function Idle (Group : Cast) return Boolean is
   begin
      for I in Group'Range loop
         if Group (I).Live_Count > 0 or else Group (I).Has_Pending then
            return False;
         end if;
      end loop;
      return True;
   end Idle;

   procedure Append_Shots
     (Trace : in out Shot_Lists.Vector;
      Group : Cast;
      Items : Bag;
      At_Tick : Natural)
   is
      Here : constant Boolean := Any_Here (Items);
      Shot : Snapshot;
   begin
      for I in Group'Range loop
         Shot.Tick := At_Tick;
         Shot.Ident := Peds.Ident (Group (I).Walker);
         Shot.X := Peds.Tile_X (Group (I).Walker);
         Shot.Y := Peds.Tile_Y (Group (I).Walker);
         Shot.Along := Peds.Along (Group (I).Walker);
         Shot.Facing := Peds.Facing (Group (I).Walker);
         Shot.State := Peds.State_Of (Group (I).Walker);
         Shot.Has_Action := Group (I).Has_Action;
         Shot.Action := Group (I).Action;
         Shot.Rest_Count := Group (I).Rest_Count;
         Shot.Rest := Group (I).Rest;
         Shot.Item_Here := Here;
         Trace.Append (Shot);
      end loop;
   end Append_Shots;

   function Run
     (M : Map.City;
      Start : Cast;
      Items : Bag;
      Max_Ticks : Natural) return Shot_Lists.Vector
   is
      Group : Cast := Start;
      Stuff : Bag := Items;
      Trace : Shot_Lists.Vector;
   begin
      Append_Shots (Trace, Group, Stuff, 0);
      for At_Tick in 1 .. Max_Ticks loop
         exit when Idle (Group);
         Tick (Group, M, Stuff);
         Append_Shots (Trace, Group, Stuff, At_Tick);
      end loop;
      return Trace;
   end Run;

end Megacorp.Actions;
