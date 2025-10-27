# Offset-Snap Tool для SketchUp (API 2020): пошаговая реализация

> **Цель**: реализовать интерактивный инструмент с привязками и смещением на основе официального SketchUp Ruby API 2020. Инструмент должен поддерживать все этапы от фиксации базовой точки до расширенных режимов работы и пользовательских настроек.

## 1. Подготовка окружения

1. Убедитесь, что установлен SketchUp 2020 или новее с поддержкой Ruby 2.7.
2. Создайте структуру плагина в `%AppData%/SketchUp/SketchUp 2020/SketchUp/Plugins` (Windows) или `~/Library/Application Support/SketchUp 2020/SketchUp/Plugins` (macOS):
   ```text
   offset_snap_tool/
   ├── offset_snap_tool.rb
   └── offset_snap/
       ├── loader.rb
       ├── tool.rb
       ├── state_manager.rb
       ├── snap_engine.rb
       ├── direction_resolver.rb
       ├── offset_calculator.rb
       ├── renderer.rb
       ├── ui_feedback.rb
       ├── geometry_creator.rb
       └── history_manager.rb
   ```
3. В файле `offset_snap_tool.rb` разместите единственный `require` на загрузчик `offset_snap/loader.rb`.
4. Обеспечьте неймспейс, например `module OffsetSnapTool`, чтобы избежать конфликтов с другими расширениями.

## 2. Общий каркас и StateManager

1. Создайте класс `StateManager`, отвечающий за:
   - текущий режим (`:idle`, `:hovering`, `:base_locked`, `:preview`, `:commit`, `:chain_mode`);
   - сохранение ключевых точек (`@base_point`, `@final_point`, `@chain_start`);
   - сохранение направлений (`@direction_mode`, `@direction_vector`);
   - управление флагами (`@offset_locked`, `@snap_enabled`, `@chain_active`).
2. Используйте неизменяемые геттеры и методы типа `lock_base(point)`, `update_preview(final_point, offset, direction)`, `reset_to_hover`.
3. Обеспечьте проверку входных данных: попытка `lock_base` без валидной точки должна вызывать `ArgumentError`.
4. Добавьте механизм подписки: каждый модуль может регистрироваться через `on_change { ... }` для минимальных перерисовок (вызов `view.invalidate` только при реальном изменении state).

## 3. Реализация Tool-скелета (задача 1)

1. Создайте класс `OffsetSnapTool::Tool` и реализуйте методы `activate`, `deactivate`, `resume`, `onMouseMove`, `onLButtonDown`, `draw`.
2. В `activate` инициализируйте `@state_manager`, `@input_point = Sketchup::InputPoint.new`, `@renderer`, `@snap_engine` и `@ui_feedback`.
3. В `onMouseMove(view, x, y)` используйте `@snap_engine.update_hover(view, x, y)`; полученный `InputPoint` сохраните в state `@state_manager.update_hover(point)`. При изменении вызывайте `view.invalidate`.
4. В `onLButtonDown(flags, x, y, view)` выполняйте FSM:
   - если `state.hovering?` → `lock_base` и показать базовый маркер;
   - если `state.base_locked?` → создайте `ConstructionPoint` через `GeometryCreator` и сбросьте состояние.
5. В `draw(view)` делегируйте `@renderer.draw_hover` или `draw_locked` в зависимости от состояния.

## 4. SnapEngine и базовые привязки (задача 1)

1. `SnapEngine` хранит один `Sketchup::InputPoint` и методы:
   - `update_hover(view, x, y)` → `@input_point.pick(view, x, y)`; возвращает объект `HoverResult` с полями `position`, `edge`, `face`, `valid?`.
   - Кешируйте `(x, y)` чтобы избежать повторных `pick` при неподвижном курсоре.
2. В `StateManager.update_hover` проверяйте `result.valid?`; если нет — оставайтесь в `:idle`.
3. В `Renderer#draw_hover(view, input_point)` вызовите `input_point.draw(view)`.

## 5. Динамическое смещение (задача 2)

1. Создайте `DirectionResolver` с режимом `:free` по умолчанию.
2. Метод `calculate(view, x, y, base_point)` должен использовать `view.pickray(x, y)` для получения `(origin, ray_dir)`.
3. Вычислите ближайшую точку `cursor_point` на луче к `base_point` (проекция точки на луч). Полученный вектор `u = (cursor_point - base_point).normalize`.
4. `OffsetCalculator` реализует:
   - `dynamic_offset(base_point, cursor_point, u)` → `(cursor_point - base_point).dot(u)`.
   - `final_point(base_point, u, distance)` → `base_point.offset(u, distance)`.
5. В `onMouseMove`, когда база зафиксирована:
   - найдите `u` через `DirectionResolver`;
   - рассчитайте `d` и `final_point` через `OffsetCalculator`;
   - обновите state и HUD через `UIFeedback`.
6. `Renderer` рисует линию `view.draw(GL_LINES, base_point, final_point)` и маркер `view.draw_points`.

## 6. Ввод через VCB (задача 3)

1. `UIFeedback` добавляет метод `update_vcb(offset)` → `Sketchup.set_status_text` и `Sketchup.set_status_text(Sketchup.format_length(offset), SB_VCB_VALUE)`.
2. Обработайте `onUserText(text, view)`:
   - `length = Sketchup.parse_length(text)`; при `nil` — проигнорируйте.
   - `@state_manager.lock_offset(length)`; `DirectionResolver` не должен пересчитывать `u`, только переиспользовать текущий.
   - Вызовите `view.invalidate`.
3. При входе в состояние `:base_locked` сбрасывайте `offset_locked` и `explicit_offset`.

## 7. Блокировка по осям (задача 4)

1. В `DirectionResolver` добавьте режимы `:axis_x`, `:axis_y`, `:axis_z`.
2. Реализуйте `set_axis(axis)` и `clear_lock`.
3. В обработчике `onKeyDown(key, repeat, flags, view)` ловите `VK_RIGHT`, `VK_LEFT`, `VK_UP` и вызывайте `direction_resolver.set_axis(X_AXIS)` и `view.lock_inference(X_AXIS)`.
4. При `onKeyUp` без модификаторов сбрасывайте блокировку (если требуется soft-lock).
5. `Renderer` должен рисовать вспомогательную ось (`GL_LINES` с большим отрезком) в соответствующем цвете.

## 8. Параллельно ребру (задача 5)

1. `SnapEngine` расширьте отслеживанием `hover_edge` и `edge_transformation = @input_point.transformation`.
2. В `DirectionResolver#set_edge(edge, transformation)` возьмите `direction = edge.line[1]`; примените `direction.transform!(transformation)`; нормализуйте.
3. В `onKeyDown` ловите `VK_MENU` и при наличии `hover_edge` вызывайте `set_edge`.
4. В `Renderer` подсвечивайте ребро через `view.draw(GL_LINE_STRIP, edge.vertices.map(&:position))` или `view.drawing_color = [255, 128, 0]`.

## 9. Нормаль к грани (задача 6)

1. `SnapEngine` хранит `hover_face`.
2. В `DirectionResolver#set_face(face, transformation)` используйте `normal = face.normal`; трансформируйте через `normal.transform!(transformation.inverse.transpose)`.
3. В `onKeyDown` ловите клавишу «N» (`key == 'N'.ord`).
4. В `Renderer` подсвечивайте грань полупрозрачным треугольником (`view.draw(GL_TRIANGLES, face.mesh.points)`).

## 10. HUD и визуализация (задача 7)

1. В `UIFeedback#render_hud(view, mouse_position, state)` выводите текст со статусом режима и текущим расстоянием.
2. Разместите HUD через `view.draw_text(mouse_position.offset(15, -15), text)`.
3. Расширьте `Renderer` цветовой схемой:
   - базовая точка: оранжевый крест `view.draw_points([base_point], 10, 2, 'x')` + круг `view.draw(GL_LINE_LOOP, circle_points)`;
   - финальная точка: заполненный квадрат через `view.draw(GL_QUADS, square_points)`.
4. Реализуйте «призрак» будущей геометрии: создавайте массив вершин и рисуйте полупрозрачным цветом через `view.drawing_color = Sketchup::Color.new(255, 128, 0, 128)`.

## 11. Магнитные значения (задача 8)

1. В `OffsetCalculator#snap_to_round(distance)` перебирайте массив шагов `[0.1.m, 0.25.m, 0.5.m, 1.m, 2.5.m, 5.m]` или используйте текущие единицы.
2. Рассчитывайте `tolerance = step * 0.05`; если `|(distance - step)| <= tolerance`, возвращайте `step`.
3. Поддержите отрицательные значения: применяйте `step * distance < 0 ? -step : step`.
4. Добавьте флаг `@snap_enabled`, переключаемый через `Ctrl` в `onKeyDown`.
5. В HUD отображайте статус `Snap: ON/OFF`.

## 12. Режим цепочки (задача 9)

1. Добавьте класс `GeometryCreator` для управления транзакциями SketchUp (`model.start_operation('Offset Snap', true)`).
2. Реализуйте `create_point(point)` и `create_edge(start, finish)`; в chain-режиме объединяйте в одну операцию до выхода из инструмента.
3. `StateManager` хранит `@chain_active` и `@chain_start`. При каждом клике в режиме цепочки обновляйте базу `@state_manager.lock_base(final_point)`.
4. Позвольте выходить из цепочки по `Esc` (`onCancel(reason, view)`), `Enter` или двойному клику.
5. Рендерьте историю сегментов: храните массив точек и отрисовывайте его `view.draw(GL_LINE_STRIP, points)`.

## 13. История смещений (задача 10)

1. Создайте `HistoryManager` с методами `load_defaults`, `push(value)`, `previous`, `next`, `reset`.
2. Читайте/записывайте историю через `Sketchup.read_default('OffsetSnapTool', 'offset_history', [])` и `write_default`.
3. На `activate` показывайте последнее значение серым в VCB (`Sketchup.set_status_text('Last: 250mm', SB_VCB_LABEL)`).
4. Используйте стрелки `VK_OEM_PLUS`/`VK_OEM_MINUS` или `VK_UP`/`VK_DOWN` для переключения истории.

## 14. Контекстное меню и настройки (задача 11)

1. Реализуйте `getMenu(menu)` в Tool:
   - `menu.add_item('Toggle Snap') { toggle_snap }`
   - `menu.add_item('Reset History') { history_manager.reset }`
   - `menu.add_item('Settings…') { ui_feedback.show_settings_dialog }`
2. Для настроек создайте `UIFeedback::SettingsDialog` на основе `UI::HtmlDialog` (API 2018+), формирующий JSON с выбранными шагами, цветами, горячими клавишами.
3. Настройки храните через `write_default('OffsetSnapTool', 'settings', json_string)` и применяйте в `activate`.

## 15. Тестирование и отладка

1. Используйте Ruby-консоль SketchUp для логирования (`SKETCHUP_CONSOLE.show` и `puts`).
2. Добавьте флаг `DEBUG = Sketchup.read_default('OffsetSnapTool', 'debug', false)`; при `true` выводите дополнительную информацию о состоянии.
3. Проверьте все режимы:
   - базовая фиксация и создание точек;
   - ввод через VCB, в том числе отрицательные значения;
   - блокировки осей, параллельное ребро, нормали;
   - магнитные значения и их отключение;
   - режим цепочки и отмена (`model.abort_operation`).
4. Тестируйте на сложных моделях, чтобы проверить производительность и корректность кеширования `InputPoint`.

## 16. Распространение

1. Создайте `.rbz` архив: упакуйте весь каталог `offset_snap_tool` в ZIP и переименуйте расширение в `.rbz`.
2. Подготовьте документацию с описанием горячих клавиш, режимов и настроек.
3. Подготовьте иконки и меню в SketchUp (например, через `UI::Command` и `UI::Toolbar`).
4. Поддерживайте версионность (например, `module OffsetSnapTool; VERSION = '1.0.0' end`).

## 17. Дальнейшие улучшения

- Добавьте поддержку смещения по двум опорным точкам (двойная привязка).
- Интегрируйте режим «следующий профиль» для создания параллельных ребер.
- Сохраняйте пользовательские шаблоны шагов снапа.
- Реализуйте экспорт/импорт настроек в JSON.
- Добавьте автоматические тесты через `TestUp` (официальный фреймворк SketchUp для Ruby тестов).

Следуя этому гайду, вы получите полнофункциональный Offset-Snap Tool, соответствующий API SketchUp 2020, с модульной архитектурой и широкими возможностями по адаптации под потребности пользователей.
