var sig Object {  -- 'var' говорит о том, что сигнатура
                  -- (множество объектов) может меняться со временем
                  -- у нас оно будет меняться в конце цикла сборки мусора,
                  -- когда будут удаляться недостижимые объекты

var linked_to: set Object  -- отношение linked_to тоже может меняться со временем
                           -- заметьте, что 'var' у сигнатуры не делает изменяемыми
                           -- отношения объявленные вместе с сигнатурой, им нужно
                           -- дополнительно ставить 'var'
}

one sig Context { -- это контекст сборщика мусора
  var marked: set Object, -- множество уже промаркированных объектов,
                          -- которые являются достижимыми из множества
                          -- корневых объектов
  var root_objects: set Object, -- множество корневых объектов
  var to_be_checked: set Object -- а в этом множестве мы будем держать объекты
                                -- которые собираемся просмотреть в будущем
}

fact init {
  -- начальное состояние
  no marked -- никакие объекты не промаркированы
  some root_objects -- есть некоторые множество корневых объектов
  to_be_checked = root_objects -- множество готовящихся к проверке объектов
                               -- при инициализации эквивалентно множеству корневых
}

-- шаг маркировки достижимых объектов
pred mark {

  -- берём какой-нибудь объект из списка проверяемых
  some o : Context.to_be_checked {

    let lnk = o.linked_to -- все дочерние обхекты
    | let lnk_unmarked = lnk - Context.marked -- которые ещё немаркированны
    | Context.to_be_checked' = Context.to_be_checked + lnk_unmarked - o -- добавляем в множество проверяемых,
                                                                        -- а сам объект из этого множества удаляем
                                                                        -- вопрос: можно ли написать так:
                                                                        -- Context.to_be_marked - o + lnk_unmarked ?
                                                                        -- а почему?

    -- добавляем его к списку промаркированных
    Context.marked' = Context.marked + o
  }

  -- всё остальное неизменно
  Object' = Object
  root_objects' = root_objects
  linked_to' = linked_to
}

-- финальная сборка
pred collect {

  -- все промаркированные считаем живыми
  Object' = Context.marked

  -- в следующем моменте, множество маркированных обнуляем
  no marked'

  -- всё остальное остаётся неизменным
  linked_to' = linked_to
  to_be_checked' = to_be_checked
  root_objects' = root_objects
}

-- шаг прокрастинации :)
pred nop {
  -- ничего не делаем и ничего не меняем
  Object' = Object
  marked' = marked
  linked_to' = linked_to
  to_be_checked' = to_be_checked
  root_objects' = root_objects
}

pred gc {
  not is_done => mark -- пока не завершили, продолжаем маркировать

  -- если нет объектов для просмотра и список маркированных не пуст,
  -- то значит сборщик мусора закончил маркировку и нужно выполнить
  -- финальный шаг по сборке мусора
  is_done and some marked => collect

  -- если всё сделали, то отдыхаем :)
  is_done and no marked => nop
}

-- добавление корневого объекта
pred add_root_object[o: Object] {
  root_objects' = root_objects + Context -> o -- само добавление

  -- моделирование барьера
  -- добавляем этот объект к объектам для будущей обработки
  -- если он ещё не промаркирован
  to_be_checked' = to_be_checked + (Context -> o - marked)

  linked_to' = linked_to -- связи между объектами не меняются
}

-- удаление корневого объекта
pred remove_root_object[o: Object] {
  root_objects' = root_objects - Context -> o -- само удаление

  -- моделирование барьера
  -- удаляем объект из множества проверяемых
  to_be_checked' = to_be_checked - Context->o

  linked_to' = linked_to
}

-- создаём связь между двумя объектами
pred link_objects[o1,o2:Object] {
  linked_to' = linked_to + o1 -> o2

  -- тут моделируется барьер
  o1 in Context.marked => 
    to_be_checked' = to_be_checked + (Context->o2 - marked)
    else to_be_checked' = to_be_checked
}

-- отлинковываем объекты
pred unlink_objects[o1, o2: Object] {
  linked_to' = linked_to - o1 -> o2

  to_be_checked' = to_be_checked -- тут ничего не меняем
                                 -- удалить o2 (если он там есть)
                                 -- из списка to_be_checked мы не можем
                                 -- так как на o2 могут указывать указатели других объектов,
                                 -- не только o1
}

pred mutator {
  -- это имитация работы пользовательской программы
  -- во время работы сборщика мусора

  -- неизменяемые вещи нужно явно указать
  Object' = Object

  -- добавим или удалим из корневых какой-нибудь случайный объект
  some o : Object | add_root_object[o] or remove_root_object[o]

  -- случайным образом слинкуем/разлинкуем пару объектов
  some o1,o2 : Object -- выберем пару случайных объектов
  | link_objects[o1, o2] or unlink_objects[o1, o2] -- и слинкуем или разлинкуем их
}

-- процесс работы, задаётся макросом для удобства
let dynamic_work {
  -- всегда
  always {
    -- либо программа что-то поменяла в объектах
    (not is_done and mutator) or

    -- либо выполнили шаг сборщика мусора
    gc
  }

  -- добавим условие, что когда-либо работа сборщика закончится,
  -- чтобы не возиться с условиями fairness
  -- это не совсем правильно, но для простоты учебной модели
  -- можно пойти на это упрощение 
  eventually is_done -- именно отсутсвие этого условия привело к контрпримеру
                     -- в конце видеолекции

  -- по-хорошему, то, что процесс сборки мусора завершится,
  -- нужно показывать на liveness свойствах с fairness условиями
  -- но мы тут срезали немного угол :)
}

-- процесс работы в случае отсутствия изменения корневых объектов,
-- связей и тд.
let static_work { always gc } -- работает только сборщик мусора

-- предикат завершения маркировки объектов
pred is_done {
  no to_be_checked -- когда не осталось объектов для маркировки
}

-- возвращает множество достижимых
fun reachable[objs:Object] : set Object {
  objs + objs.^linked_to -- достижимыми считаем сами объекты и те, до которых можно дойти
                         -- по отношению linked_to
}

-- признак того, что маркировка закончена и следующий шаг - сборка мусора
pred pre_collect {
  is_done and some marked
}

-- помотрим примеры того, что получается
run {
   -- тут зададим такие условия, чтобы получить ситуацию сборки мусора,
   -- то есть потребуем такие модели, чтобы в них как минимум один
   -- объект получался мусорным и его бы убирал сборщих мусора 

   static_work => { -- режим работы - без мутаций

     -- чтобы было интереснее, потребуем минимум 3 корневых объекта
     -- иначе грустно пустые множества созерцать :)
     #root_objects >= 3 and
     eventually -- тогда, когда-то в будущем
     (some o: Object -- найдём такой объект
      | o not in reachable[Context.root_objects] -- что он будет недостижим из корневых, то есть
                                               -- это будет мусорный объект
     )

     -- когда-то в будущем, процесс сборки мусора завершится
     -- и все оставшиеся объекты будут достижимыми из корневых
     eventually always (is_done and Object = reachable[Context.root_objects])
   }
} for 6 but 1..20 steps

-- проверка того, что в статичном режиме (когда пользовательский процесс ничего
-- не меняет в системе) сборщик мусора не оставляет мусора и не удаляет достижимые объекты
-- для динамического режима работы это условие слишком сильно
-- (сильно усложнит модель дополнительная информация в контексте для
-- точного отслеживания действий пользователя)
assert static_correct {
  static_work => eventually always (is_done and Object = reachable[Context.root_objects])
}

-- проверка динамического режима, что сборщик мусора корректно работает
-- в режиме когда меняются корневые объекты и связи между объектами
assert dynamic_correct {
  dynamic_work => {
    -- все достижимые промаркированны
    eventually {
      pre_collect => {
        reachable[Context.root_objects] in Context.marked
        -- так как в динамическом режиме может получиться, что мы промаркируем объект,
        -- но он потом выпадет из достижимых (связь изменилась, например), то в общем
        -- случае marked больше или равно reachable

        -- в следующий момент будет произведена сборка мусора
        -- и marked будет обнулён
        after always {
          is_done and no marked
        }
      }
    }
  } 
}

static_correctness: check static_correct for 5 but 1..20 steps
dynamic_correctness: check dynamic_correct for 5 but 1..20 steps
