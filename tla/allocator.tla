----------------------------- MODULE allocator -----------------------------

\* Подключаем модули для целых чисел (Integers)
\* для использования Assert (TLC)
\* и для вычисления размеров множеств - Cardinality (FiniteSets)
EXTENDS Integers, TLC, FiniteSets

\* Эти константы будут потом принимать конкретные значения,
\* которые мы зададим в настройках моделирования
CONSTANTS LowestAddress, HighestAddress, BlockHdrSize

\* Небольшие проверки корректности задания констант
ASSUME BlockHdrSize \in Int \* \in - предикат принадлежности элемента множеству
ASSUME LowestAddress \in Int /\ LowestAddress >= 0
ASSUME HighestAddress \in Int
       /\ HighestAddress > LowestAddress + BlockHdrSize

\* A .. B задаёт множество из элементов от A до B
\* по аналогии с заданием интервалов, например [0..2]
Address == LowestAddress .. HighestAddress
MemSize == HighestAddress - LowestAddress

Size == 0 .. MemSize

\* {a,b,c} - задание множества перечислением его элементов
Status == {"free", "occupied"}

\* задаём множество всех возможных заголовков блоков, т.е.:
\* { [Sz |-> 0, St |-> "free"], [Sz |-> 0, St |-> "occupied"] ... }
BlockHdrs == [Sz: Size, St: Status] \* это примерно как множество пар в декартовом произведении двух множеств

\* выбираем некий UNDEF, такой, что он не принадлежит множеству
\* всех возможных заголовков блоков
UNDEF == CHOOSE b: b \notin BlockHdrs

\* Тут задаём множество всех возможных блоков
Blocks == [A: Address, Sz: Size, St: Status]

\* Это вспомогательные определения для задания заголовка блока и для самого блока
BLKHDR(size, status) == [Sz |-> size,  St |-> status]
BLK(addr, size, status) == [A |-> addr, Sz |-> size, St |-> status]


\* Начальное состояние памяти: первое слово - заголовок единственного свободного
\* блока размером со всю память, остальные слов неопределены - UNDEF
InitialMem == [[a \in Address |-> UNDEF]
               EXCEPT ![LowestAddress] = BLKHDR(MemSize, "free")]

\* Начало алгоритма аллокатора на PlusCal
(*--algorithm allocator

\* Глобальные пересенные
variable MemoryPool = InitialMem,
         allocations = 0,
         temp_block = UNDEF;

\* Вспомогательные определения
define

  SizeOfBlockAt(addr) == MemoryPool[addr].Sz
  BlockAtAddress(addr) ==
    BLK(addr, SizeOfBlockAt(addr), MemoryPool[addr].St)

  NextBlockAddress(block) == block.A + block.Sz
  
  IsFree(block) ==
    LET st == "free"
    IN st \in Status /\ block.St = st
  
  IsOccupied(block) ==
    LET st == "occupied"
    IN st \in Status /\ block.St = st
  
  IsSplittable(block) == block.Sz > BlockHdrSize * 2
  
  HeaderOf(block) == BLKHDR(block.Sz, block.St)
  
  ForAllBlocks(op(_,_), acc) ==
    LET getblocks[addr \in Address] ==
      IF addr = HighestAddress THEN acc
      ELSE
        LET block == BlockAtAddress(addr)
        IN op(block, getblocks[NextBlockAddress(block)])
    IN getblocks[LowestAddress]
  
  AllBlocksSize == ForAllBlocks(LAMBDA b, acc: b.Sz + acc, 0)
  AllFreeBlocksSize ==
    ForAllBlocks(LAMBDA b, acc: IF IsFree(b) THEN b.Sz + acc ELSE acc, 0)
  AllOccupiedBlocksSize ==
    ForAllBlocks(LAMBDA b, acc: IF IsOccupied(b) THEN b.Sz + acc ELSE acc, 0)

  AllBlocks == ForAllBlocks(LAMBDA b, acc: {b} \union acc, {})
  AllFreeBlocks ==
    ForAllBlocks(LAMBDA b, acc: IF IsFree(b) THEN {b} \union acc ELSE acc, {})
  AllOccupiedBlocks ==
    ForAllBlocks(LAMBDA b, acc: IF IsOccupied(b) THEN {b} \union acc ELSE acc, {})
  
  HasPrev(block) == block.A # LowestAddress
  HasNext(block) == NextBlockAddress(block) < HighestAddress
  
  NextBlock(block) == BlockAtAddress(NextBlockAddress(block))
  
  PrevBlock(block) ==
    CHOOSE b \in AllBlocks: NextBlockAddress(block) = b.A

  PossibleSizesToSplit(block) == BlockHdrSize .. (block.Sz - BlockHdrSize)
 
  SomeFreeBlocksPresent == Cardinality(AllFreeBlocks) # 0
  SomeOccupiedBlocksPresent == Cardinality(AllOccupiedBlocks) # 0
  
  NoFragmentation ==
    \A b \in AllFreeBlocks:
      /\ ~HasPrev(b) \/ ~IsFree(PrevBlock(b))
      /\ ~HasNext(b) \/ ~IsFree(NextBlock(b))
  
end define;

macro allocate() begin
  if SomeFreeBlocksPresent then
    with b \in AllFreeBlocks do
      either \* allocate full block
        MemoryPool[b.A] := BLKHDR(b.Sz, "occupied");
        allocations := allocations + 1; 
      or \* split and allocate lower part
        if IsSplittable(b) then
          with s \in PossibleSizesToSplit(b) do
            MemoryPool[b.A] := BLKHDR(s, "occupied") ||
            MemoryPool[b.A + s] := BLKHDR(b.Sz - s, "free");
            allocations := allocations + 1;             
          end with;
        end if;
      end either;
    end with;
  end if;
end macro;

begin
again:
  assert (NoFragmentation);
  assert (allocations >= 0);
  assert (allocations = 0 => MemoryPool = InitialMem);
  assert (AllBlocksSize = MemSize);
  assert (AllBlocksSize = AllFreeBlocksSize + AllOccupiedBlocksSize);

  either goto allocate;
  or     goto free;
  end either;

allocate:
  allocate();
  goto again;

free:
  if ~SomeOccupiedBlocksPresent then
    goto again;
  end if;
  
select_block:
  with b \in AllOccupiedBlocks do
    temp_block := b;
  end with;
  
check_prev:
  if HasPrev(temp_block) /\ IsFree(PrevBlock(temp_block)) then
    with prev = PrevBlock(temp_block);
         new_block = BLK(prev.A, prev.Sz + temp_block.Sz, "free")
    do
      MemoryPool[new_block.A] := HeaderOf(new_block) ||
      MemoryPool[temp_block.A] := UNDEF;
      temp_block := new_block;
    end with;
  end if;

check_next:
  if HasNext(temp_block) /\ IsFree(NextBlock(temp_block)) then
    with next = NextBlock(temp_block);
         new_block = BLK(temp_block.A, temp_block.Sz + next.Sz, "free")
    do
      MemoryPool[new_block.A] := HeaderOf(new_block) ||
      MemoryPool[next.A] := UNDEF;
    end with;
  else
    MemoryPool[temp_block.A] := BLKHDR(temp_block.Sz, "free");
  end if;
  temp_block := UNDEF;
  allocations := allocations - 1;
  goto again;
end algorithm;
*)
\* BEGIN TRANSLATION - the hash of the PCal code: PCal-ef5c8071e891d7b3365408ed10551cf7
VARIABLES MemoryPool, allocations, temp_block, pc

(* define statement *)
SizeOfBlockAt(addr) == MemoryPool[addr].Sz
BlockAtAddress(addr) ==
  BLK(addr, SizeOfBlockAt(addr), MemoryPool[addr].St)

NextBlockAddress(block) == block.A + block.Sz

IsFree(block) ==
  LET st == "free"
  IN st \in Status /\ block.St = st

IsOccupied(block) ==
  LET st == "occupied"
  IN st \in Status /\ block.St = st

IsSplittable(block) == block.Sz > BlockHdrSize * 2

HeaderOf(block) == BLKHDR(block.Sz, block.St)

ForAllBlocks(op(_,_), acc) ==
  LET getblocks[addr \in Address] ==
    IF addr = HighestAddress THEN acc
    ELSE
      LET block == BlockAtAddress(addr)
      IN op(block, getblocks[NextBlockAddress(block)])
  IN getblocks[LowestAddress]

AllBlocksSize == ForAllBlocks(LAMBDA b, acc: b.Sz + acc, 0)
AllFreeBlocksSize ==
  ForAllBlocks(LAMBDA b, acc: IF IsFree(b) THEN b.Sz + acc ELSE acc, 0)
AllOccupiedBlocksSize ==
  ForAllBlocks(LAMBDA b, acc: IF IsOccupied(b) THEN b.Sz + acc ELSE acc, 0)

AllBlocks == ForAllBlocks(LAMBDA b, acc: {b} \union acc, {})
AllFreeBlocks ==
  ForAllBlocks(LAMBDA b, acc: IF IsFree(b) THEN {b} \union acc ELSE acc, {})
AllOccupiedBlocks ==
  ForAllBlocks(LAMBDA b, acc: IF IsOccupied(b) THEN {b} \union acc ELSE acc, {})

HasPrev(block) == block.A # LowestAddress
HasNext(block) == NextBlockAddress(block) < HighestAddress

NextBlock(block) == BlockAtAddress(NextBlockAddress(block))

PrevBlock(block) ==
  CHOOSE b \in AllBlocks: NextBlockAddress(b) = block.A

PossibleSizesToSplit(block) == BlockHdrSize .. (block.Sz - BlockHdrSize)

SomeFreeBlocksPresent == Cardinality(AllFreeBlocks) # 0
SomeOccupiedBlocksPresent == Cardinality(AllOccupiedBlocks) # 0

NoFragmentation ==
  \A b \in AllFreeBlocks:
    /\ ~HasPrev(b) \/ ~IsFree(PrevBlock(b))
    /\ ~HasNext(b) \/ ~IsFree(NextBlock(b))


vars == << MemoryPool, allocations, temp_block, pc >>

Init == (* Global variables *)
        /\ MemoryPool = InitialMem
        /\ allocations = 0
        /\ temp_block = UNDEF
        /\ pc = "again"

again == /\ pc = "again"
         /\ Assert((NoFragmentation), 
                   "Failure of assertion at line 116, column 3.")
         /\ Assert((allocations >= 0), 
                   "Failure of assertion at line 117, column 3.")
         /\ Assert((allocations = 0 => MemoryPool = InitialMem), 
                   "Failure of assertion at line 118, column 3.")
         /\ Assert((AllBlocksSize = MemSize), 
                   "Failure of assertion at line 119, column 3.")
         /\ Assert((AllBlocksSize = AllFreeBlocksSize + AllOccupiedBlocksSize), 
                   "Failure of assertion at line 120, column 3.")
         /\ \/ /\ pc' = "allocate"
            \/ /\ pc' = "free"
         /\ UNCHANGED << MemoryPool, allocations, temp_block >>

allocate == /\ pc = "allocate"
            /\ IF SomeFreeBlocksPresent
                  THEN /\ \E b \in AllFreeBlocks:
                            \/ /\ MemoryPool' = [MemoryPool EXCEPT ![b.A] = BLKHDR(b.Sz, "occupied")]
                               /\ allocations' = allocations + 1
                            \/ /\ IF IsSplittable(b)
                                     THEN /\ \E s \in PossibleSizesToSplit(b):
                                               /\ MemoryPool' = [MemoryPool EXCEPT ![b.A] = BLKHDR(s, "occupied"),
                                                                                   ![b.A + s] = BLKHDR(b.Sz - s, "free")]
                                               /\ allocations' = allocations + 1
                                     ELSE /\ TRUE
                                          /\ UNCHANGED << MemoryPool, 
                                                          allocations >>
                  ELSE /\ TRUE
                       /\ UNCHANGED << MemoryPool, allocations >>
            /\ pc' = "again"
            /\ UNCHANGED temp_block

free == /\ pc = "free"
        /\ IF ~SomeOccupiedBlocksPresent
              THEN /\ pc' = "again"
              ELSE /\ pc' = "select_block"
        /\ UNCHANGED << MemoryPool, allocations, temp_block >>

select_block == /\ pc = "select_block"
                /\ \E b \in AllOccupiedBlocks:
                     temp_block' = b
                /\ pc' = "check_prev"
                /\ UNCHANGED << MemoryPool, allocations >>

check_prev == /\ pc = "check_prev"
              /\ IF HasPrev(temp_block) /\ IsFree(PrevBlock(temp_block))
                    THEN /\ LET prev == PrevBlock(temp_block) IN
                              LET new_block == BLK(prev.A, prev.Sz + temp_block.Sz, "free") IN
                                /\ MemoryPool' = [MemoryPool EXCEPT ![new_block.A] = HeaderOf(new_block),
                                                                    ![temp_block.A] = UNDEF]
                                /\ temp_block' = new_block
                    ELSE /\ TRUE
                         /\ UNCHANGED << MemoryPool, temp_block >>
              /\ pc' = "check_next"
              /\ UNCHANGED allocations

check_next == /\ pc = "check_next"
              /\ IF HasNext(temp_block) /\ IsFree(NextBlock(temp_block))
                    THEN /\ LET next == NextBlock(temp_block) IN
                              LET new_block == BLK(temp_block.A, temp_block.Sz + next.Sz, "free") IN
                                MemoryPool' = [MemoryPool EXCEPT ![new_block.A] = HeaderOf(new_block),
                                                                 ![next.A] = UNDEF]
                    ELSE /\ MemoryPool' = [MemoryPool EXCEPT ![temp_block.A] = BLKHDR(temp_block.Sz, "free")]
              /\ temp_block' = UNDEF
              /\ allocations' = allocations - 1
              /\ pc' = "again"

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == pc = "Done" /\ UNCHANGED vars

Next == again \/ allocate \/ free \/ select_block \/ check_prev
           \/ check_next
           \/ Terminating

Spec == Init /\ [][Next]_vars

Termination == <>(pc = "Done")

\* END TRANSLATION - the hash of the generated TLA code (remove to silence divergence warnings): TLA-d08662d6167f7b4a11e3abdcff3c51ce

=============================================================================
\* Modification History
\* Last modified Mon Nov 09 14:11:50 MSK 2020 by d00559749
\* Created Mon Nov 09 12:16:17 MSK 2020 by d00559749
