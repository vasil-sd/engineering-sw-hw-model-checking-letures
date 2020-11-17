----------------------------- MODULE allocator -----------------------------

(*
Подключаем нужные модули:
1. Integers - для работы с целыми числами
2. TLC - для использования оператора ASSERT
3. FiniteSets - для оператора Cardinality - вычисления размера конечных множеств
*)
EXTENDS Integers, TLC, FiniteSets

(*
Это внешние параметры модуля, которые задаются при моделировании
либо при подключении в другой модуль.

В текущем модлуле они просто считаются предопределёнными константами.
*)
CONSTANTS LowestAddress, HighestAddress, BlockHdrSize

(*
Тут небольшая проверка корректности заданных параметров.
*)
ASSUME BlockHdrSize \in Int 
ASSUME LowestAddress \in Int /\ LowestAddress >= 0
ASSUME HighestAddress \in Int
       /\ HighestAddress > LowestAddress + BlockHdrSize

\* Множество возможных адресов, задано интервалом
Address == LowestAddress .. HighestAddress
\* Размер всего пула памяти
MemSize == HighestAddress - LowestAddress

\* Множество всех возможных размеров
Size == 0 .. MemSize

\* Статусы блоков, задано перечислением {A,B,C}
Status == {"free", "occupied"}

(* Множество записей всех заголовков блоков, задано примерно как 
   декартовым произведением множества размеров на множество статусов
*)
BlockHdrs == [Sz: Size, St: Status]

(*
CHOOSE - оператор, похожий на аксиому выбора в теории множеств
он выбирает произвольное значение из множества, которое удовлетворяет
заданному условию.
В данном случае мы выбираем некое значение, которое не принадлежит множеству
заголовков блоков.
Будем его сипользовать как признак невалидного заголовка блока.
*)
UNDEF == CHOOSE b: b \notin BlockHdrs

\* множество всех возможных блоков памяти
Blocks == [A: Address, Sz: Size, St: Status]

\* Вспомогательные определения для компактности и читаемости спеки
BLKHDR(size, status) == [Sz |-> size,  St |-> status]
BLK(addr, size, status) == [A |-> addr, Sz |-> size, St |-> status]

(* Начальное состояние памяти: везде UNDEF, кроме первой ячейки,
   в которой заголовок единственного свободного блока размером
   во всю память.
*)
InitialMem == [[a \in Address |-> UNDEF]
               EXCEPT ![LowestAddress] = BLKHDR(MemSize, "free")]

\* Относительно fair - см. видео 5.2, 5.3
(*--fair algorithm allocator

\* Переменные состояния
variable MemoryPool = InitialMem,
         allocations = 0, \* тут будем учитывать количество аллокаций/деаллокаций
         temp_block = UNDEF;

\* вспомогательные определения, довольно близкие к C++ коду
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

  (* ForAllBlocks - это мета-определение, которое принимает двух-местную функцию или оператор
     и начальное значение аккумулятора, затем делает свёртку множества блоков примерно
     как fold_left в функциональных языках программирования:
     fold_left(fun, acc, set) = fun(set[0], fun(set[1] ...., fun(set[Last], acc)))....)))
  *)
  ForAllBlocks(op(_,_), acc) ==
    LET getblocks[addr \in Address] == \* определяем локальную вспомогательную функцию
      IF addr = HighestAddress THEN acc \* дошли до самого верхнего блока
      ELSE
        LET block == BlockAtAddress(addr)
        IN op(block, getblocks[NextBlockAddress(block)])
    IN getblocks[LowestAddress]

  \* LAMBDA params: expression - это безымянная функция
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

  \* # - это знак "не равно", аналог != в C/C++
  HasPrev(block) == block.A # LowestAddress
  HasNext(block) == NextBlockAddress(block) < HighestAddress

  NextBlock(block) == BlockAtAddress(NextBlockAddress(block))

  (* Тут можно обратить внимание на ещё один способ использования CHOOSE.
     Благодаря этому мы можем обойтись без симулирования дополнительных
     структур, типа двусвязного списка.
     Это, конечно, немного не так как в реальном C++ коде, но для нашей
     задачи (проверка сегментации свободных блоков) вполне допустимое
     упрощение.
  *)
  PrevBlock(block) ==
    CHOOSE b \in AllBlocks: NextBlockAddress(b) = block.A

  PossibleSizesToSplit(block) == BlockHdrSize .. (block.Sz - BlockHdrSize)

  SomeFreeBlocksPresent == Cardinality(AllFreeBlocks) # 0
  SomeOccupiedBlocksPresent == Cardinality(AllOccupiedBlocks) # 0

  (* Основное свойство, что мы хотим проверить.
     Для всех свободных блоков: у каждого свободного блока не должно
     быть смежного с ним свободного.
  *)
  NoFragmentation ==
    \A b \in AllFreeBlocks:
      /\ ~HasPrev(b) \/ ~IsFree(PrevBlock(b))
      /\ ~HasNext(b) \/ ~IsFree(NextBlock(b))

end define;

(* Так как основная задача - это проверка возможной фрагментации
   свободных блоков, то основной фокус на точном моделировании операции
   "free", так как именно она ответственна за дефрагментацию.
   Поэтому "allocate" моделируем максимально просто, чтобы сэкономить
   как на написании спеки, так и на времени моделирования.
*)
macro allocate() begin
    with b \in AllFreeBlocks do \* выбираем произвольный блок из всех свободных
        if IsSplittable(b) then
          (* Если блок можно разделить, то мы либо аллоцируем его целиком,
             либо разделяем и аллоцируем часть.
             Относительно изменений в данном макросе (allocate), по сравнению
             с первоначальным вариантом, смотри видео 5.2.
          *)
          either \* allocate full block
            MemoryPool[b.A] := BLKHDR(b.Sz, "occupied");
          or \* split and allocate lower part
            with s \in PossibleSizesToSplit(b) do
              MemoryPool[b.A] := BLKHDR(s, "occupied") ||
              MemoryPool[b.A + s] := BLKHDR(b.Sz - s, "free");
            end with;
          end either;
        else
          \* блок слишком мелкий для разделения, поэтому аллоцируем целиком
          MemoryPool[b.A] := BLKHDR(b.Sz, "occupied");
        end if;
        allocations := allocations + 1;
    end with;
end macro;

(* Основная идея - это перебор в бесконечном цикле всех возможных вариантов аллокаций и
   деаллокаций блоков. Так как в спеке у нас несколько точек недетерминизма, то в каждой
   такой точке mode-checker породит все возможные состояния и переходы в них. Таким
   образом, нам, благодаря недетерминизму, не нужно задавать явного алгоритма перебора
   вариантов (в явном алгоритме придётся ещё и доказывать, что он переберёт все варианты
   и ничего не пропустит).
   То есть, недетерминизм - это очень мощный инструмент для разработки спецификаций.
*)
begin
again:
  assert (NoFragmentation); \* тут всё ясно
  assert (allocations >= 0); \* деаллокаций не может быть больше, чем аллокаций, небольшая перестраховка
  (* Независимо от последовательности выделения/освобождения блоков, если всё, что мы аллоцировали
     в конечном итоге было освобождено, то память должна вернуться в первоначальное состояние
     (один большой свободный блок с заголовком в первой ячейке памяти)
  *)
  assert (allocations = 0 => MemoryPool = InitialMem);
  \* сохранение размеров
  assert (AllBlocksSize = MemSize);
  assert (AllBlocksSize = AllFreeBlocksSize + AllOccupiedBlocksSize);

  \* недетерминированно выбираем:
  either
         \* если есть что аллоцировать, то идём на аллокацию
         if SomeFreeBlocksPresent then
            goto allocate;
         else
            goto again;
         end if;
  or    \* если можем что-то освободить, то на "free"
        if SomeOccupiedBlocksPresent then
            goto free;
        else
            goto again;
        end if;
  end either;

allocate:
  allocate();
  goto again;

free: skip;

select_block: \* недетерминированно выбираем како-либо блок из занятых
  with b \in AllOccupiedBlocks do
    temp_block := b;
  end with;

check_prev: \* проверяем не является ли предыдущий блок свободным
  if HasPrev(temp_block) /\ IsFree(PrevBlock(temp_block)) then
    \* если предыдущий тоже свободный, то объединяем их
    with prev = PrevBlock(temp_block);
         new_block = BLK(prev.A, prev.Sz + temp_block.Sz, "free")
    do
      MemoryPool[new_block.A] := HeaderOf(new_block) ||
      MemoryPool[temp_block.A] := UNDEF;
      temp_block := new_block;
    end with;
  end if;

check_next: \* проверяем следующий блок
  if HasNext(temp_block) /\ IsFree(NextBlock(temp_block)) then
    \* если следующий свободный - то объединяем
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
\* BEGIN TRANSLATION - the hash of the PCal code: PCal-b359d446a8c30d9b7f06f589406a23ae
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
                   "Failure of assertion at line 119, column 3.")
         /\ Assert((allocations >= 0), 
                   "Failure of assertion at line 120, column 3.")
         /\ Assert((allocations = 0 => MemoryPool = InitialMem), 
                   "Failure of assertion at line 121, column 3.")
         /\ Assert((AllBlocksSize = MemSize), 
                   "Failure of assertion at line 122, column 3.")
         /\ Assert((AllBlocksSize = AllFreeBlocksSize + AllOccupiedBlocksSize), 
                   "Failure of assertion at line 123, column 3.")
         /\ \/ /\ IF SomeFreeBlocksPresent
                     THEN /\ pc' = "allocate"
                     ELSE /\ pc' = "again"
            \/ /\ IF SomeOccupiedBlocksPresent
                     THEN /\ pc' = "free"
                     ELSE /\ pc' = "again"
         /\ UNCHANGED << MemoryPool, allocations, temp_block >>

allocate == /\ pc = "allocate"
            /\ \E b \in AllFreeBlocks:
                 IF IsSplittable(b)
                    THEN /\ \/ /\ MemoryPool' = [MemoryPool EXCEPT ![b.A] = BLKHDR(b.Sz, "occupied")]
                               /\ allocations' = allocations + 1
                            \/ /\ \E s \in PossibleSizesToSplit(b):
                                    /\ MemoryPool' = [MemoryPool EXCEPT ![b.A] = BLKHDR(s, "occupied"),
                                                                        ![b.A + s] = BLKHDR(b.Sz - s, "free")]
                                    /\ allocations' = allocations + 1
                    ELSE /\ MemoryPool' = [MemoryPool EXCEPT ![b.A] = BLKHDR(b.Sz, "occupied")]
                         /\ allocations' = allocations + 1
            /\ pc' = "again"
            /\ UNCHANGED temp_block

free == /\ pc = "free"
        /\ TRUE
        /\ pc' = "select_block"
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

Spec == /\ Init /\ [][Next]_vars
        /\ WF_vars(Next)

Termination == <>(pc = "Done")

\* END TRANSLATION - the hash of the generated TLA code (remove to silence divergence warnings): TLA-f4951ea3ec185ec3c7839d133f1e2a64

(*
WF_vars(Next) == <>[](ENABLED( <<Next>>_vars )) => []<>(<<Next>>_vars)

<<Next>>_vars == Next /\ (vars' # vars)
*)

=============================================================================
\* Modification History
\* Last modified Mon Nov 16 20:07:23 MSK 2020 by d00559749
\* Last modified Mon Nov 16 11:11:00 MSK 2020 by d00559749
\* Last modified Mon Nov 09 14:11:50 MSK 2020 by d00559749
\* Created Mon Nov 09 12:16:17 MSK 2020 by d00559749
