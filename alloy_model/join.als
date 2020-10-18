module join[Time]

open order[Time]
open memory[Time]
open block[Time]
open address
open size as s

-- этот вспомогательный предикат объединяет блоки
pred UpdateBlocks[now: Time, Bbelow, Babove: Block] {
  let past = now.prev {
    -- у нижнего блока остаётся старый адрес
    Bbelow.Addr.now = Bbelow.Addr.past
    -- размер увеличивается на размер верхнего блока
    Bbelow.Size.now = Sum[Bbelow.Size.past, Babove.Size.past]

    -- верхний блок уходит в нивидимые
    -- следующие два утвержения можно записать короче: 'Babove.Invisible[now]'
    Babove.Size.now = zero
    Babove.Addr.now = null
  }
}

-- это основной предикат объединения блоков
pred JoinBlocks[now: Time, B1, B2: Block] {
  let past = now.prev {
    -- две ветки для случая разных положений блоков друг относительно друга
    {
      B2 = B1.Above[past]
      now.UpdateBlocks[B1, B2]
    }
    or
    {
      B1 = B2.Above[past]
      now.UpdateBlocks[B2, B1]
    }
  }
}

-- смотрим модели
Example: run {
  all now: Time - first
  | let past = now.prev {
    past.MemStructureValid -- это утверждение сильнее чем нужно, как показано в видео можно немного ослабить
    some disj b1,b2: past.VisibleBlocks { -- для каких-то двух различных видимых блоков
      now.JoinBlocks[b1,b2] -- объединяем их в момент времени 'now'
      now.BlocksAreTheSameExcept[b1+b2] -- с 'past' до 'now' поменялись только 'b1' и 'b2' - рамочный предикат
    }
  }
} for 6 but exactly 2 Time -- двух моментов времени вполне достаточно

-- тут проверяем то, что 'JoinBlocks' сохраняет инвариант валидности структуры памяти
assert JoinIsCorrectlyDefined {
  all now: Time - first
  | let past = now.prev
  | {
      #past.VisibleBlocks > 1 -- для работы 'JoinBlocks' нужно как минимум два блока в момент 'past'
      past.MemStructureValid -- и в 'past' структура памяти должна быть валидной
    }
    implies -- наличие двух и более видимых блоков и валидность памяти в 'past'
            -- позволяет проверить следующее:
    some disj b1, b2 : past.VisibleBlocks -- для любых двух различных видимых блоков в 'past' 
    | past.Neighbors[b1 + b2] implies { -- если они соседние
       {
          now.JoinBlocks[b1,b2] -- то мы можем их объединить в момент времени 'now'
          now.BlocksAreTheSameExcept[b1 + b2] -- меняются только объединяемые блоки в момент 'now'
       }
       implies -- и это вседга должно приводить к
         now.MemStructureValid -- валидной структуре памяти в момент 'now'
    }
}

-- тут проверяем удверждение о сохранении инварианта
CheckJoin: check JoinIsCorrectlyDefined for 7 but exactly 2 Time
-- двух моментов времени должно быть достаточно, так как все предикаты связанные с динамическими операциями
-- определены на двух моментах времени: текущем и предыдущем
-- в видео показан процесс отладки предикатов и модели, когда находятся контр-примеры

