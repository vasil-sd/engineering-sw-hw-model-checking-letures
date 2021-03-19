module address

open size -- подключаем модуль size

open order[Address] as o -- вводим линейный порядок над Address

/*
Небольшое пояснение про абстрактные сигнатуры.

Абстрактные сигнатуры в чём-то похожи на абстрактные классы в С++ или интерфейсы в Java.

Они должны быть потом расширены 'extends' реальными сигнатурами.

Те сигнатуры, что расширяют конкретную абстрактную сигнатуру, они:
1. полностью её покрывают (то есть их объединение равно множеству атомов в абстрактной сигнатуре)
2. неперекрываются, то есть disjoint, не имеют общих элементов.

Используя эти свойства, мы введём абстрактную сигнатуру 'AddrSpace', которая будет расширена
сигнатурой 'null' (с единственным элементом) и 'Address' - сигнатурой всех валидных адресов.

Более подробное объяснение можно посмотреть в видео.
*/

one sig null extends AddrSpace {} -- обратите внимание на мультипликатор 'one' - ровно один элемент

sig Address extends AddrSpace {}

abstract sig AddrSpace {
  Add: Size -> AddrSpace -- это отношение, как было рассказано в предыдущих видео, на самом деле
                         -- тернарное 'AddrSpace -> Size -> AddrSpace'
                         -- оно определяет результирующий адрес для суммы адреса и размера/смещения
}

one sig lowest in Address {} { lowest = o/first }
one sig highest in Address {} { highest = o/last }

-- Add : LHS:AddrSpace -> RHS:Size -> AddrSpace
fun Sum[LHS: AddrSpace, RHS: Size] : AddrSpace { LHS.Add[RHS] }

-- Add : Lower:AddrSpace -> Size -> Upper:AddrSpace
-- Distance возвращает размер/смещение между адресами
fun Distance[Lower: AddrSpace, Upper: AddrSpace] : Size { Lower.Add.Upper }

fact {
  -- если к адресу прибавляем нулевой размер/смещение получаем этот же адрес
  all a: AddrSpace | Sum[a, zero] = a

  -- 'null' - особенный элемент: какой бы размер/смещение мы к нему ни добавили, всегда получим 'null'
  -- для чего так определены опрации для 'null' подробнее рассказано в видео
  all s: Size | Sum[null, s] = null

  -- если к любому валидному адресу добавить ненулевой размер/смещение, то получим больший адрес
  all a: Address | all s: Size - zero | greater[Sum[a,s], a]

  -- Add : LHS:AddrSpace -> RHS:Size -> AddrSpace
  -- так как размеры/смещения строго упорядочены, и среди них нет одинаковых, то
  -- от меньшего адреса к большему есть только один размер/смещение, то есть
  -- нет такой ситуации, когда добавляя к адресу два разных размера/смещения мы получим
  -- один и тот же результирующий адрес
  all disj a1,a2: Address | greater[a2, a1] implies one Distance[a1, a2]

  -- Нельзя получить меньший адрес из большего добавлением какого-либо размера/смещения
  all disj a1,a2: Address | less[a2, a1] implies no Distance[a1, a2]

  -- добавляя к адресу больший размер/смещение - получим больший адрес
  all s1, s2: Size | all a:Address | greater[s1,s2] implies {
    greater[Sum[a, s1], Sum[a, s2]]
  }

  -- Если адреса идут в порядке a1,a2,a3, то расстояние от a1 до a3 больше, чем
  -- расстояние от a1 до a2 и больше, чем от a2 до a3
  all disj a1,a2,a3: Address | less[a1, a2] and less[a2,a3] implies {
    less[Distance[a1,a2], Distance[a1,a3]]
    less[Distance[a2,a3], Distance[a1,a3]]
  }
}

-- дополнительный предикат для удобства, проверяет, что в переданном множестве адресов нет 'null'
pred not_null[A: set AddrSpace] {  null not in A }

example: run {} for 7
