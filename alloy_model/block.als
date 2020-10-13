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

/*
Тут вводится концепцию видимости блоков, подробное объяснение этого есть в видео.
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

-- этот предикат - часть так называемых frame axioms
-- говорит о том, что с предыдущего момента времени до 'Tnow'
-- изменились только указанные блоки, остальные остались неизменны.
-- подробнее о frame problem и способах решения см. https://en.wikipedia.org/wiki/Frame_problem
pred BlocksAreTheSameExcept[Tnow: Time, Bs: set Block] {
  let Tpast = Tnow.prev {
    all B: Block - Bs {
      B.Addr.Tnow = B.Addr.Tpast
      B.Size.Tnow = B.Size.Tpast
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

-- тут посмотрим на то, как работает framing предикат:
-- между любыми двумя последовательными моментами времени
-- измениться может только (и ровно) один блок (мультипликтор one)
example: run {
  all t: Time - first | one b : Block | t.BlocksAreTheSameExcept[b]
} for 4 but exactly 5 Block -- блоков ровно 5 во всех моделях, остальные сигнатуры от 0 до 4 атомов
