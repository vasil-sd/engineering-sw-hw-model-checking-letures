module block[Time]

/*
Так как при моделировании операций над блоками нам потребуется концепция времени,
то этот модуль параметризован некоторой сигнатурой 'Time'.
От элементов которой нам нужно только свойство упорядоченности.
*/

open order[Time]

open size as s

open address as a

/*
Основные атрибуты блока памяти - это адрес и размер.

Так как адрес и размер блока могут меняться со временем при выполнении операций над
структурой памяти, то эти атрибуты заданы тернарными отношениями:
Addr: Block -> AddrSpace -> Time, какому блоку какие адреса в какой момент времени соответствуют
Size: Block -> Size -> Time, аналогично для размеров
*/
sig Block {
  Addr: AddrSpace one -> Time,
  Size: s/Size one -> Time
} {
  /*
  Тут задаём основное свойство блоков (инвариант): блок или имеет адрес 'null' и размер 'zero' или
  валидный адрес и ненулевой размер.
  */
  all t: Time
  | (Addr.t = null and Size.t = zero) or (not_null[Addr.t] and non_zero[Size.t])
}

fun lowest_block[Bs: set Block, t: Time] : set Block {
  { b: Bs | b.Addr.t = minimum[Bs.Addr.t]}
}

fun but_lowest[Bs: set Block, t: Time] : set Block {
  Bs - Bs.lowest_block[t]
}

fun SizeOfAll[Bs : set Block, t: Time] : one Size {
  no Bs implies zero else
  #Bs = 1 implies Bs.Size.t else
  #Bs = 2 implies Bs.Size2[t] else 
  #Bs = 3 implies Bs.Size3[t] else 
  #Bs = 4 implies Bs.Size4[t] else 
  #Bs = 5 implies Bs.Size5[t] else 
  #Bs = 6 implies Bs.Size6[t] else 
  #Bs = 7 implies Bs.Size7[t] else 
  #Bs = 8 implies Bs.Size8[t] else
  zero
}

fun Size2[Bs: set Block, t: Time] : one Size {
  Sum[(Bs.lowest_block[t]).Size.t, (Bs.but_lowest[t]).Size.t]
}

fun Size3[Bs: set Block, t: Time] : one Size { Sum[(Bs.lowest_block[t]).Size.t, Size2[Bs.but_lowest[t], t]] }
fun Size4[Bs: set Block, t: Time] : one Size { Sum[(Bs.lowest_block[t]).Size.t, Size3[Bs.but_lowest[t], t]] }
fun Size5[Bs: set Block, t: Time] : one Size { Sum[(Bs.lowest_block[t]).Size.t, Size4[Bs.but_lowest[t], t]] }
fun Size6[Bs: set Block, t: Time] : one Size { Sum[(Bs.lowest_block[t]).Size.t, Size5[Bs.but_lowest[t], t]] }
fun Size7[Bs: set Block, t: Time] : one Size { Sum[(Bs.lowest_block[t]).Size.t, Size6[Bs.but_lowest[t], t]] }
fun Size8[Bs: set Block, t: Time] : one Size { Sum[(Bs.lowest_block[t]).Size.t, Size7[Bs.but_lowest[t], t]] }

Example_SizeOfAll: run {
  all t: Time | #t.VisibleBlocks > 2 and some s: s/Size | s = SizeOfAll[t.VisibleBlocks, t] 
} for 6 but 3 Block

/*
Тут вводится концепция видимости блоков, подробное объяснение этого есть в видео.
Блок видимый только тогда, когда его адрес не 'null' и размер не 'zero'.
*/
one sig BlockVisibility {
  Visible: set Block -> Time, -- множество видимых блоков в конкретный момент времени
  Invisible: set Block -> Time -- аналогично - множество невидимых
} {
  all t: Time | Invisible.t = Addr.t.null + Size.t.zero
  all t: Time | Visible.t = Block - Invisible.t
}

-- эти функции для удобства и читабельности определений в спецификациях
fun VisibleBlocks[T:Time] : set Block { BlockVisibility.Visible.T }
fun InvisibleBlocks[T:Time]: set Block { BlockVisibility.Invisible.T }

-- предикаты, которые говорят о том видим ли блок в конкретный момент времени или нет
pred Visible[B: Block, T:Time] { B in T.VisibleBlocks }
pred Invisible[B: Block, T:Time] { B in T.InvisibleBlocks }

/*
Функция получения первого адреса памяти, который следует сразу после блока
*/
fun NextBlockAddr[B: Block, T: Time] : AddrSpace { 
  Sum[B.Addr.T, B.Size.T]
}

/*
Предикат проверки того, что указанный адрес принадлежит блоку памяти
*/
pred InBlock[A:Address, B:Block, T:Time] {
  greater_or_equal[A, B.Addr.T]
  less[A, B.NextBlockAddr[T]]
}

-- этот предикат понадобится в определении опреции 'malloc'
-- когда большой пустой блок нужно разрезать на два
-- этот предикат определяет можно ли заданный блок разрезать в
-- заданный момент времени
pred Splittable[B: Block, T: Time] {
  some a: Address
  | some s1,s2 : s/Size - zero {
    a.InBlock[B, T]
    a != B.Addr.T
    B.Size.T = Sum[s1,s2]
  }
}

-- этот предикат - часть так называемых frame axioms
-- говорит о том, что с предыдущего момента времени до 'Tnow'
-- изменились только указанные блоки, остальные остались неизменны.
-- подробнее о frame problem и способах решения см. https://en.wikipedia.org/wiki/Frame_problem
pred BlocksAreTheSameExcept[now: Time, Bs: set Block] {
  let past = now.prev {
    all B: Block - Bs {
      B.Addr.now = B.Addr.past
      B.Size.now = B.Size.past
    }
  }
}

/*
Проверяем, что мы правильно задали определения для свойства видимости блоков:
1. объединение множеств видимых и невидимых блоков в каждый момент времени должно быть равно
   множеству всех блоков
2. множества видимых и невидимых не пересекаются ни в какой момент времени

То есть: в любой момент времени каждый блок либо видим, либо невидим, и 
в любой момент времени блок не может быть одновремено видимым и невидимым.
*/
check1: check {
  all t: Time | t.VisibleBlocks + t.InvisibleBlocks = Block
  all t: Time | no t.VisibleBlocks & t.InvisibleBlocks
} for 7

example: run {
  -- в каждый момент времени, есть по крайней мере один блок, который можно
  -- разделить на два
  all t: Time | some b: Block | b.Splittable[t]

  -- тут посмотрим на то, как работает framing предикат:
  -- между любыми двумя последовательными моментами времени
  -- измениться может только (и ровно) один блок (мультипликтор one)
  all t: Time - first | one b : Block | t.BlocksAreTheSameExcept[b]
} for 4 but exactly 5 Block -- блоков ровно 5 во всех моделях, остальные сигнатуры от 0 до 4 атомов
