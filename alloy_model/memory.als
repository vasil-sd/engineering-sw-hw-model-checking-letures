module memory[Time]

open order[Time]
open block[Time]

open size
open address

/*
  Тут определяются свойства блоков относительно положения в памяти.
  Highest - самый верхний блок
  Lowest - самый нижний
  Middle - все посередине

  Свойства могут меняться в моменты времени поэтому определены как отношения Block -> Time.

  Определение этих свойств через сигнатуру, а не предикаты, позволяет потом
  лучше их визуализировать (например, раскрашивать блоки), в видео это показано подробнее
*/
one sig Position {
  Highest: Block -> Time,
  Lowest: Block -> Time,
  Middle: Block -> Time
} {
  all t: Time | Highest.t = { b: Block | b.NextBlockAddr[t] = highest }
  all t: Time | Lowest.t = { b: Block | b.Addr.t = lowest }
  all t: Time | Middle.t = t.VisibleBlocks - (Highest.t + Lowest.t)
}

-- Тут проверка того, что все видимые блоки у нас классифицированы по положению в памяти
CheckPosition: check {
  all t: Time
  | Position.Highest.t + Position.Lowest.t + Position.Middle.t = t.VisibleBlocks
} for 6

-- эти функции для удобства записи спецификаций
fun highest[T: Time] : set Block { Position.Highest.T }
fun lowest[T: Time] : set Block { Position.Lowest.T }
fun middle[T: Time] : set Block { Position.Middle.T }

/*
  Тут задаётся наличие непосредственных соседей сверху и снизу блока.
*/
one sig Neighborhood {
  Above: Block -> Block -> Time,
  Below: Block -> Block -> Time
} {
  all t: Time
  | all b: Block
  | b.Above.t = { b1: Block | b.NextBlockAddr[t] = b1.Addr.t }

  all t: Time
  | all b: Block
  | b.Below.t = { b1: Block | b1.NextBlockAddr[t] = b.Addr.t }
}

-- для удобства, определим пару функций
fun Above[Bbelow: Block, T: Time] : set Block { Neighborhood.Above.T[Bbelow] }
fun Below[Babove: Block, T: Time] : set Block { Neighborhood.Below.T[Babove] }

-- проверяем правильность задания добрососедских отношений :)
-- то есть, любой блок для соседа сверху является соседом снизу
CheckNeighborhood: check {
  all t: Time | Neighborhood.Above.t = ~(Neighborhood.Below.t) 
} for 6

-- получить все блоки над данным блоком в заданный момент времени
fun AllAbove[Bbelow: Block, T: Time] : set Block {
  ^(Neighborhood.Above.T)[Bbelow]
}

-- все блоки ниже данного в заданный момент времени
fun AllBelow[Babove: Block, T:Time] : set Block {
  ^(Neighborhood.Below.T)[Babove]
}

-- проверка того, что заданное множество блоков в заданный момент времени
-- является непрерывной цепочкой соседних блоков
pred Neighbors[T: Time, Bs: set Block] {
  let all_paths_up = ^(Bs <: (Neighborhood.Above.T))
  | let all_paths_down = ^(Bs <: (Neighborhood.Below.T)) {
    all b: Bs {
      one b.Above[T] or one b.Below[T]
      b.all_paths_up in b.AllAbove[T]
      b.all_paths_down in b.AllBelow[T]
    }
  }
}

-- Проверяем, что при валидной структуре памяти, все видимые блоки
-- являются цепочкой соседей
CheckNeighborsPred: check {
  all t: Time | t.MemStructureValid implies t.Neighbors[t.VisibleBlocks]
} for 7

-- тут примеры цепочек соседей
ExampleNeighbors: run {
  all t: Time {
    t.MemStructureValid
    t.Neighbors[t.VisibleBlocks]
    #t.VisibleBlocks > 2
  }
} for 6

/*
  Дальше начинаются предикаты основных свойств структуры памяти
*/

-- Все заданные блоки в заданный момент времени не перекрываются
pred NoOverlapping[Bs: set Block, T: Time] {
  all disj b1, b2: Bs
  | no a: Address
  | a.InBlock[b1, T] and a.InBlock[b2, T]
}

-- Между заданными блоками нет дыр, то есть, есть самый верхний, самый нижний,
-- и у всех блоков есть соответствующие непосредственные соседи
pred NoHoles[Bs: set Block, T: Time] {
  highest[T] in Bs
  lowest[T] in Bs
  all b: Bs & middle[T] | one b.Above[T] and one b.Below[T]
  -- ниже два условия для учёта того, что один блок от начального адреса до
  -- конечного тоже является валидной структурой памяти
  (highest[T] != lowest[T] and one highest[T].Below[T] and one lowest[T].Above[T])
  or
  (highest[T] = lowest[T] and no highest[T].Below[T] and no lowest[T].Above[T])
  -- можно было бы задать это так: #highest[T].Below[T] = #lowest[T].Above[T]
}

-- верхние границы блоков находятся внутри пула памяти,
-- то есть, для каждого блока в данный момент времени
-- есть адрес, который следует сразу за блоком
pred NoOverruns[Bs: set Block, T:Time] {
  all b: Bs | some b.NextBlockAddr[T]
}

-- это основной предикат валидности структуры памяти
-- в момент времени T
pred MemStructureValid[T: Time] {
  let blocks = T.VisibleBlocks {
    blocks.NoOverlapping[T]
    blocks.NoHoles[T]
    blocks.NoOverruns[T]
  }
}

pred SumOfBlockSizesIsConstant[now: Time] {
  let past = now.prev
  | past.VisibleBlocks.SizeOfAll[past] = now.VisibleBlocks.SizeOfAll[now]
}

-- смотрим результирующие модели структур памяти
example: run {
  -- в каждый момент времени, есть по крайней мере один блок, который можно
  -- разделить на два
  all t: Time | some b: t.VisibleBlocks | b.Splittable[t]

  -- в каждый момент времени структура памяти валидна
  all t: Time | t.MemStructureValid

  -- хотим, чтобы в каждый момент времени видимых блоков было больше 3
  all t: Time | #t.VisibleBlocks > 3
} for 7

-- тут просмотр моделей для процесса отладки предиката 'NoHoles'
-- подробнее см. видео
DebugNoHoles: run {
  all t: Time | #t.VisibleBlocks = 1 and t.MemStructureValid
} for 6
