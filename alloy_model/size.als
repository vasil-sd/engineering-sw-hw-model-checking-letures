module size

open order[Size] as o -- подключаем модуль линейного порядка и параметризуем его сигнатурой 'Size'

sig Size { Add: Size -> Size } -- объявляем сигнатуру 'Size' и отношение 'Add'

/*
Немного про способы задания операций/функций в Alloy (да и в логике тоже).
Простые операции, можно определить через выражения, используя 'fun'

Но часть бывает удобно определить функцию/операцию через отношение.

Например, операция сложения может быть определена как тернарное отношение:
'A + B = C' == 'Sum(A,B,C)', где Sum - это отношение или предикат, который
становится истинным, на тех триплетах, которые отвечают уравнению 'A + B = C'

В данном случае операция сложения у нас несколько специфическая, поэтому её проще
определить через отношение.

Ещё напомню, что отношение 'Add' привязано к сигнатуре 'Size', как метод у класса в Java.
Поэтому в действительности оно трёхместное, где первый параметр неявный, как this/self у
методов класса.

То есть, отношение 'Add' на самом деле такое: 'Size -> Size -> Size'

Будем считать, что первый два параметра это 'A' и 'B' соответственно, а последний 'C' - 
результат их сложения.
*/

--fun zero : one Size { o/first } -- для удобства введём константу 'zero'
--fun max : one Size { o/last } -- и 'max'

-- вместо функций zero/max лучше сделать дополнительные сигнатуры
-- это нужно, чтобы потом на просмотрщике моделей нормально были видны
-- 'zero' и 'max' атомы.
one sig zero in Size {} {zero = o/first}
one sig max in Size {} {max = o/last}

-- Для удобства определим функцию 'Sum', чтобы запись сложения была привычнее
fun Sum[LHS, RHS: Size] : Size { LHS.Add[RHS] }

fun SumAll[S : set Size] : one Size {
  no S implies zero else
  #S = 1 implies S else
  #S = 2 implies S.Sum2 else
  #S = 3 implies S.Sum3 else
  #S = 4 implies S.Sum4 else
  #S = 5 implies S.Sum5 else
  #S = 6 implies S.Sum6 else
  #S = 7 implies S.Sum7 else
  #S = 8 implies S.Sum8 else
  zero
}

fun Sum2[S : set Size] : one Size { Sum[S.minimum, S - S.minimum] }
fun Sum3[S : set Size] : one Size { Sum[S.minimum, Sum2[S - S.minimum]] }
fun Sum4[S : set Size] : one Size { Sum[S.minimum, Sum3[S - S.minimum]] }
fun Sum5[S : set Size] : one Size { Sum[S.minimum, Sum4[S - S.minimum]] }
fun Sum6[S : set Size] : one Size { Sum[S.minimum, Sum5[S - S.minimum]] }
fun Sum7[S : set Size] : one Size { Sum[S.minimum, Sum6[S - S.minimum]] }
fun Sum8[S : set Size] : one Size { Sum[S.minimum, Sum7[S - S.minimum]] }

example_SumAll: run { some s1,s2,s3 : Size | SumAll[s1+s2] = s3 } for 7

-- теперь свойства нашей операции/отношения
-- по аналогии с математической операцией
fact {
  all s1, s2: Size | Sum[s1, s2] = Sum[s2, s1] -- перестановка слагаемых не меняет результат (коммутативность)
  all s: Size | Sum[zero, s] = s -- ноль является нейтральным элементом
  all s1, s2, s3: Size | Sum[Sum[s1,s2],s3] = Sum[s1, Sum[s2,s3]] -- ассоциативность
}

-- а тут более специализированные свойства
fact {
  all s1, s2:Size | lone Sum[s1,s2] -- для любых 'Size' их сумма, если определена, то однозначно
  all s: Size - zero | no Sum[max, s] -- максимальный ни с каким кроме 'zero' сложить нельзя
  -- b > c следовательно a + b > a + c для всех a из 'Size'
  all s1,s2,s3:Size | greater[s2, s3] implies greater[Sum[s1,s2], Sum[s1, s3]]

  -- а вот это специальное свойство, оно делает отношение максимальным,
  -- в видеоролике есть более подробные объяснения
  all s: Size | #Sum[s, Size] = add[#s.all_greater, 1]
}

-- дополнительный предикат для удобства, проверяет, что в переданном множестве размеров нет нулевого размера
pred non_zero[S: set Size] { zero not in S }

-- просмотр моделей по 5 элементов 'Size'
-- 'Size' всегда будет максимальное количество элементов, которое позволяет
-- настройка, так как модуль 'order' у параметра имеет атрибут 'exactly'
example: run {} for 5
