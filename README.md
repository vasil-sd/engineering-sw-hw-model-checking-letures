Обзорный курс по model-checking/model-finding, читаемый осенью 2020 для студентов 2-го курса МФТИ.


Ссылки на видео (по номерам лекций):

1. https://youtu.be/QxJNpxemI4I

2. https://youtu.be/sMTRU8ts4ZA

3. https://youtu.be/yNZaVtMJ6Js - Спецификация структуры памяти на Alloy

  - 3.1. https://youtu.be/AjtCH8pCU6s - небольшое введение в работу с Alloy Analyzer, модуль линейного порядка
  - 3.2. https://youtu.be/wP00Ts_UG_M - небольшой пример, как настраивать отображение моделей в Alloy Analyzer
  - 3.3. https://youtu.be/COs4d7fsOfk - Alloy модуль size. Моделирование размеров блоков.
  - 3.4. https://youtu.be/eoXQwIjTbvc - Alloy модуль address. Спецификация адресов блоков.
  - 3.5. https://youtu.be/DgMFm0UWwKI - Alloy модуль block. Спецификация на блоки памяти.
  - 3.6. https://youtu.be/vWnERS7L-M8 - Alloy модуль memory. Основные свойства структуры памяти. Предикат корректности структуры памяти.
  - 3.7. https://youtu.be/t_ho_HMeym0 - Alloy модуль операции разделения блока.
  - 3.8. https://youtu.be/zf_oiDN63VY - Alloy модуль операции объединения блоков.
  - 3.9. https://youtu.be/4RZ-AA9qnCg - Добавление инварианта константности суммы размеров блоков в Alloy модель.

4. https://youtu.be/CKhG5zf4xZQ - Простой менеджер памяти на основе моделей Alloy. Пояснения к исходному коду на C++.


5. Проверка динамических свойств аллокатора с помощью TLA+:

  - 5.1. https://youtu.be/xLRhdWBb4Tc - TLA+/PlusCal спецификация аллокатора памяти. Проверка некоторых динамических свойств, проверка
         отсутсвия фрагментации свободной памяти. Предварительное видео.
  - 5.2. https://youtu.be/PmPsRABU-hs - лекция. Основы TLA+, PlusCal. Моделирование свойств "живости" (liveness)
  - 5.3. https://youtu.be/DhMK-WFcRcA - дополнение к лекции 5.2 с ответом на вопрос в конце лекции про stuttering и liveness свойства.
  
6. https://youtu.be/XiqNwYT_hC4 - Введение в автоматическое управление памятью

7. https://youtu.be/zmt6miCTNF8 - Модель GC на Electrum2 (расширение Alloy)
8. https://youtu.be/bMFCQHasGDY - Реализация GC на C++

Общие ссылки про матлогику, model-checking и пр:
================================================

1. Книга Карпова Юрия Глебовича "Model-checking. Верификация параллельных и распределённых программных систем.".

   К сожалению, в настоящий момент не издаётся. Но можно найти в интернете (ссылку не привожу по понятным причинам).

2. Лекции Юрия Глебовича Карпова, выложенные на канале Ирины Шошминой:
   https://www.youtube.com/channel/UCF-q6CklFjA2jmqm-aJcU3w/videos?view=0&sort=da&flow=grid

   Довольно неплохое изложение многих вещей, с примерами и наглядным описанием алгоритмов. Возможно, что для младших курсов
   знания логики высказываний будет недостаточно и придётся дополнительно изучить некоторые моменты для более полного понимания
   материала лекций.


Ссылки для изучения Alloy:
==========================

1. Книга Daniel Jackson "Software Abstractions". Можно заказать на amazon: https://www.amazon.com/Software-Abstractions-Logic-Language-Analysis/dp/0262017156

   Хорошее введение в язак Alloy и инструмент Alloy Analyzer. Много примеров и пояснений. Для понимания материала достаточно базового знакомства с матлогикой. 

2. https://homepage.divms.uiowa.edu/~tinelli/classes/181/Fall17/lectures.shtml

   Тут есть хороший учебный материал по Alloy и реляционной логике с множествами.

3. https://www.hillelwayne.com/tags/alloy/

   Блог Hillel Wayne, много интересных статей с примерами использования как Alloy, так и TLA+ и других
   инструментов.

4. https://github.com/AlloyTools/models

   Много примеров промышленных моделей на Alloy.

5. https://alloy.readthedocs.io/en/latest/

   Справочник по Alloy от Hillel Wayne


Ссылки для изучения TLA+/PlusCal:
=================================

1. Основная книга по TLA+ "Specifying Systems": https://lamport.azurewebsites.net/tla/book-02-08-08.pdf

2. Видеокурс по TLA+: http://lamport.azurewebsites.net/video/videos.html

3. Сайты Hillel Waine:

  - Learn TLA+: https://learntla.com/introduction/
  - Блог: https://www.hillelwayne.com/

4. Руководства по PlusCal:

  - https://lamport.azurewebsites.net/pubs/pluscal.pdf
  - C-подобный синтаксис: https://lamport.azurewebsites.net/tla/c-manual.pdf
  - Паскаль-подобный синтаксис: https://lamport.azurewebsites.net/tla/p-manual.pdf

5. Проверка многопоточных алгоритмов с помощью PlusCal: https://lamport.azurewebsites.net/pubs/dcas.pdf

6. Примеры спецификаций: https://github.com/tlaplus/Examples

7. Список статей с примерами спецификаций: https://www.hillelwayne.com/list-of-tla-examples/

8. Статьи Рона Преслера: https://pron.github.io/
