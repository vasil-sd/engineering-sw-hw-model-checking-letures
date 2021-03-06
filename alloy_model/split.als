module split[Time]

/*
В принципе, можно тут подключить только модуль 'memory'. Так как остальные уже подключены в нём.
И использовать доступ по полным именам, например 'memory/block/s/Size'.

Но лучше все нужные модули подключать явно, чтобы пользователи (другие разработчики, коллеги)
сразу видели, какие сущности будут использоваться в данном модуле.
*/

open order[Time]
open memory[Time]
open block[Time]
open address
open size as s

/*
Это основной предикат операции разбиения блока.

Относительно того, зачем нам нужен Binvis, подробнее рассказано в видео.
*/

pred SplitBlock[now:Time, B, Binvis: Block] {
 let past = now.prev { -- 'past' - это момент времени предшествующий 'now'
   past.(B.Splittable) -- блок 'B' должен быть разделяемым на момент времени 'past'
                       -- так как в 'now' мы собираемся его разделить на два блока
   -- блок 'B' останется по старому адресу, поменяем только его размер
   B.Addr.now = B.Addr.past
   -- есть какие-то ненулевые размеры 's1' и 's2' для новых блоков,
   -- которые в сумме дают размер старого блока
   some s1, s2: s/Size - zero {
     Sum[s1,s2] = B.Size.past -- сумма размеров новых блоков равна размеру старого
     s1 = B.Size.now -- новый размер блока 'B' - 's1'
     Binvis.Size.now = s2 -- у второго блока размер 's2'
     Binvis.Addr.now = Sum[B.Addr.past, s1] -- адрес нового второго блока - это сумма адреса старого блока
                                            -- с новым размером старого блока
   }
 }
}

-- предикат для просмотра моделей структур памяти
pred SomeModel {
  all now: Time - first -- для всех моментов времени, кроме первого, так как на первом не будут определены
                        -- предикаты 'SplitBlock' и 'BlocksAreTheSameExcept', так как они определены для
                        -- момента, который передан в параметрах и для предшествующего ему, а у first
                        -- нет предшествующего
  | let past = now.prev
  | some B: past.VisibleBlocks -- есть больше одного видимого блока
  | some Binvis: past.InvisibleBlocks { -- есть больше одного невидимого блока (про видимые и невидимые есть объяснение в видео)
    past.(B.Splittable) -- 'B' разделяем в момент времени 'past'
    past.MemStructureValid -- структура памяти валидна в момент времени 'past'
    now.SplitBlock[B, Binvis] -- разделяем блок в момент 'now'
    now.BlocksAreTheSameExcept[B + Binvis] -- рамочный предикат, что меняются только блоки 'B' и 'Binvis'
    now.MemStructureValid -- в момент времени 'now' структура памяти валидна после операции split
  }
}

-- тут посмотрим некоторые модели
Example: run SomeModel for 7 but exactly 3 Time

/*
Теперь проверим, что операция 'SplitBlock', когда правильно вызвана, всегда сохраняет инвариант
валидности структуры памяти.
*/

assert SplitIsCorrectlyDefined {
  all now: Time - first
  | let past = now.prev
  -- относительно следующей импликации есть пояснение в видео:
  -- вкратце, это убирает из рассмотрения модели без блоков памяти (пустые)
  | some past.VisibleBlocks and some past.InvisibleBlocks
    implies
    some B: past.VisibleBlocks
    | some Binvis: past.InvisibleBlocks
    | {
        -- есть какие-то 'B' и 'Binvis'
        past.(B.Splittable) -- 'B' можно разделить на момент времени 'past'
        past.MemStructureValid -- в момент 'past' структура памяти валидна
        now.SplitBlock[B, Binvis] -- в момен времени 'now' разделяем блок 'B'
        now.BlocksAreTheSameExcept[B + Binvis] -- от 'past' до 'now' меняются только блоки 'B' и 'Binvis'
      }
      implies { -- это влечёт
        now.MemStructureValid -- валидность памяти в момент времени 'now'
        now.SumOfBlockSizesIsConstant
      }
}

-- Проверяем корректность определения операции
CheckSplit: check SplitIsCorrectlyDefined for 7 but exactly 2 Time, 4 Block
-- контрпримеров не найдено на всех моделях где в сигнатурах до 9 атомов включительно и ровно по 3 момента времени
-- в целом, такая область поиска контрпримеров даже немного избыточна (как примерно определять
-- достаточность размеров моделей я вкратце рассказываю в видеоролике),
-- поэтому мы можем быть уверены в том, что наше определение операции split сохраняет
-- валидность структуры памяти.
