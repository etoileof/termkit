# Документация CloseRouter API

Короткая документация по публичному inference API: модели, запросы, ключи, баланс и ошибки.

## Base URL

```
https://api.closerouter.dev/v1
```

## Авторизация

```
Authorization: Bearer closerouter_...
```

## Быстрый старт

Создайте ключ в кабинете, сохраните его на backend/server-side стороне и отправьте первый OpenAI-compatible запрос.

### Минимум для интеграции

- Используйте base URL https://api.closerouter.dev/v1.
- Передавайте ключ через Authorization: Bearer <closerouter_...> или x-api-key.
- Для POST-запросов отправляйте Content-Type: application/json.
- Не вставляйте API-ключи во frontend-код, публичные репозитории, логи и скриншоты.

### Первый запрос

```bash
export CLOSEROUTER_API_KEY="closerouter_your_key"

curl https://api.closerouter.dev/v1/chat/completions \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-5.4-mini",
    "messages": [
      { "role": "user", "content": "Reply with exactly: ok" }
    ],
    "max_tokens": 16
  }'
```

### OpenAI JavaScript SDK

```typescript
import OpenAI from 'openai';

const client = new OpenAI({
  apiKey: process.env.CLOSEROUTER_API_KEY,
  baseURL: 'https://api.closerouter.dev/v1',
});

const completion = await client.chat.completions.create({
  model: 'openai/gpt-5.4-mini',
  messages: [{ role: 'user', content: 'Reply with exactly: ok' }],
  max_tokens: 16,
});

console.log(completion.choices[0]?.message?.content);
```

### Основные endpoint-ы

| Method | Path | Description |
| --- | --- | --- |
| GET | /models | Каталог моделей, цены, modalities и поддерживаемые endpoint-ы. |
| GET | /models/count | Количество доступных моделей. |
| GET | /model-authors | Компактный список разработчиков и количество их видимых моделей. |
| GET | /models/{provider}/{model}/endpoints | Параметры и streaming для одной модели. |
| GET | /providers | Модели и доступные provider options для каждой. |
| PATCH | /providers | Сохранить provider по умолчанию для модели. |
| GET | /credits | Текущий баланс и суммарное использование аккаунта. |
| GET | /requests/{request_id} | Стоимость и usage одного inference-запроса. |
| GET | /requests | Последние запросы аккаунта с фильтрами и пагинацией. |
| GET | /usage | Статистика расходов за период по дням, моделям, провайдерам и ключам. |
| POST | /chat/completions | OpenAI-style Chat Completions. |
| POST | /responses | OpenAI Responses API. |
| POST | /messages | Anthropic-style Messages API. |
| POST | /audio/speech | Синтез речи: готовый MP3 или PCM в теле ответа. |
| POST | /images/generations | Генерация изображений. |
| POST | /images/edits | Редактирование изображений. |
| POST | /videos/submit | Создать video task. |
| GET | /videos/tasks/{task_id} | Проверить статус video task. |
| POST | /keys | Создать API-ключ аккаунта. |
| GET | /keys | Список активных ключей аккаунта. |
| PATCH | /keys/{key_id}/limit | Изменить лимит расходов и максимальные цены ключа или отдельных моделей. |
| DELETE | /keys/{key_id} | Отозвать ключ аккаунта. |

## Модели

Каталог показывает публичные ID моделей, цены, modalities, поддерживаемые параметры и endpoint-ы.

### Получить каталог

```bash
export CLOSEROUTER_API_KEY="closerouter_your_key"

curl https://api.closerouter.dev/v1/models \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"
```

### Разработчики, фильтр и пагинация

Сначала получите компактный список разработчиков, затем фильтруйте плоский каталог по точным slug. Пагинация включается только при передаче limit.

```bash
curl https://api.closerouter.dev/v1/model-authors \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"

curl "https://api.closerouter.dev/v1/models?model_authors=anthropic,openai&limit=50&offset=0" \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"
```

### Catalog endpoint-ы

| Method | Path | Description |
| --- | --- | --- |
| GET | /models | Каталог моделей, цены, modalities и поддерживаемые endpoint-ы. |
| GET | /models/count | Количество доступных моделей. |
| GET | /model-authors | Компактный список разработчиков и количество их видимых моделей. |
| GET | /models/{provider}/{model}/endpoints | Параметры и streaming для одной модели. |
| GET | /providers | Модели и доступные provider options для каждой. |
| PATCH | /providers | Сохранить provider по умолчанию для модели. |

### Как выбрать модель

- ID модели имеет формат provider/model, например openai/gpt-5.4-mini.
- model_authors=anthropic,openai использует OR между точными slug разработчиков; неизвестный slug возвращает 400 invalid_model_author.
- Фильтры разработчика, input_modalities=text,image,audio и output_modalities=text,image,video комбинируются через AND. GET /models/count принимает те же фильтры.
- Без limit GET /models остается плоским и непагинированным. limit принимает 1–1000, offset — неотрицательное число; ответ добавляет total_count и links.next.
- Ключ с model allowlist видит в каталоге, списке разработчиков, count и model detail только разрешенные модели.
- Поле endpoints показывает совместимые API: chat, responses, messages, images_generations, images_edits, videos_submit.
- Цены возвращаются в unit: usd_per_million_tokens, usd_per_image или usd_per_second.
- GET /models/{provider}/{model}/endpoints показывает supports_streaming и supported_parameters для конкретной модели.

### Бесплатные модели

- Сейчас бесплатными являются opencode/big-pickle и opencode/north-mini-code-free; определяйте их только по access.type = "free", а не по нулевой цене.
- Для бесплатных моделей нужен Telegram, привязанный к текущему аккаунту; подключить его можно на /settings.
- Все бесплатные модели, API-ключи, API endpoint-ы, Dashboard-чат и Telegram-чат делят один лимит 100 принятых запросов за календарный день UTC.
- Смена API-ключа, модели или способа вызова не создает новый лимит; provider retry и fallback внутри принятого запроса повторно не считаются.
- Бесплатный запрос может пройти с нулевым балансом и исчерпанным spend limit, но только после проверки Telegram и дневного лимита.

### Настроить reasoning effort

Сначала проверьте supported_reasoning_efforts нужного endpoint-а. reasoning_effort передается верхнеуровневым полем, а reasoning и output_config — объектами, как в примерах. Responses использует reasoning.effort; Messages — output_config.effort или верхнеуровневый reasoning_effort, если он явно указан. Значение none явно отключает reasoning у моделей, которые его публикуют; это не пропуск поля. Обычно доступны low, medium и high; xhigh и max — только у отдельных моделей. У openai/gpt-5.6-luna, openai/gpt-5.6-sol и openai/gpt-5.6-terra также доступен уровень ultra.

```
{
  "reasoning_effort": "high"
}

{
  "reasoning": {
    "effort": "high"
  }
}

{
  "output_config": {
    "effort": "high"
  }
}
```

### Получить провайдеров моделей

GET /providers возвращает selected_provider_chain в сохраненном порядке и provider options в текущем Auto-порядке с auto_rank, success rate, лимитами, возможностями и availability.

```bash
curl https://api.closerouter.dev/v1/providers \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"
```

### Выбрать провайдера для одного запроса

Передайте provider как строку: auto, provider-1, provider-5 и так далее.

```bash
curl https://api.closerouter.dev/v1/chat/completions \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-opus-4.8",
    "provider": "provider-5",
    "messages": [
      { "role": "user", "content": "Reply with exactly: ok" }
    ],
    "max_tokens": 16
  }'
```

### Сохранить одного провайдера (совместимый формат)

Старый provider-формат остается поддержан и сохраняет цепочку из одного провайдера.

```bash
curl https://api.closerouter.dev/v1/providers \
  -X PATCH \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-opus-4.8",
    "provider": "provider-5"
  }'
```

### Сохранить цепочку провайдеров

PATCH /providers сохраняет строгую цепочку на аккаунт. Порядок элементов provider_chain — порядок попыток для всех API-ключей аккаунта и кабинета /models.

```bash
curl https://api.closerouter.dev/v1/providers \
  -X PATCH \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-opus-4.8",
    "provider_chain": [
      { "name": "provider-5" },
      { "name": "provider-2" }
    ]
  }'
```

### Вернуться к Auto

provider: "auto" очищает сохраненную цепочку и возвращает автоматический выбор.

```bash
curl https://api.closerouter.dev/v1/providers \
  -X PATCH \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-opus-4.8",
    "provider": "auto"
  }'
```

### Режимы Flex, Default и Priority

- provider-9 поддерживает режимы для openai/gpt-5.6-luna, openai/gpt-5.6-sol, openai/gpt-5.6-terra, google/gemini-3.1-pro-preview, google/gemini-3.5-flash, google/gemini-3.5-flash-lite и google/gemini-3.6-flash. Для google/gemini-3.1-flash-lite сейчас доступен только Flex.
- Передайте суффикс :flex или :priority в model для точного разового выбора. Базовый ID и суффикс :default выбирают Default.
- Flex дешевле, но может дольше ждать в очереди провайдера; Default — сбалансированный режим; Priority получает максимальный приоритет обработки и стоит дороже.
- GET /providers возвращает service_tier у конкретного варианта. В кабинете /models все режимы объединены в одной карточке провайдера: кнопки меняют итоговую цену CloseRouter и ID модели, а сохранение выбранного option_id закрепляет точный режим на аккаунт.
- Auto не подменяет Default более дешевым Flex или дорогим Priority, когда у provider-9 доступны все три режима.

### Порядок и приоритеты

- Цепочка строгая: после ошибки последнего выбранного провайдера API не добавляет невыбранных Auto-провайдеров и возвращает финальную ошибку.
- provider в inference-запросе — разовый override с приоритетом над сохраненной цепочкой; provider: "auto" включает Auto только для этого запроса.
- provider.order задает порядок публичных вендоров моделей и не является сохраненной цепочкой upstream-провайдеров.
- PATCH /providers с provider: "auto" очищает сохраненную цепочку; legacy provider: "provider-5" сохраняет цепочку длиной один.
- Для точного variant-level выбора остается поддержка provider.option_id.
- Auto имеет режимы cheap (по умолчанию), fast и stable. Общий режим сохраняется на /models для всего аккаунта; модель может наследовать его или иметь свой Auto. Ручные цепочки сохраняются.
- Для одного запроса: provider: {name: "auto", strategy: "fast"}. Явный strategy имеет высший приоритет; его нельзя совмещать с конкретным provider/option_id. Старые формы auto используют закреплённый Auto ключа, затем Auto модели или аккаунта.
- В PATCH /providers поле auto_strategy: "cheap" | "fast" | "stable" сохраняет Auto модели; null или явный выбор текущего Auto аккаунта возвращает наследование. Если поле не передано, индивидуальный Auto сохраняется. Передайте provider: "auto", чтобы также очистить ручную цепочку.

## Chat Completions

OpenAI-style endpoint для chat-запросов, streaming и audio input у совместимых моделей.

### Минимальный chat-запрос

```bash
export CLOSEROUTER_API_KEY="closerouter_your_key"

curl https://api.closerouter.dev/v1/chat/completions \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-5.4-mini",
    "messages": [
      { "role": "user", "content": "Reply with exactly: ok" }
    ],
    "max_tokens": 16
  }'
```

### Streaming

Ответ приходит как Server-Sent Events: строки data: {...}, затем data: [DONE].

```
curl -N https://api.closerouter.dev/v1/chat/completions \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-haiku-4.5",
    "messages": [
      { "role": "user", "content": "Reply with exactly: ok" }
    ],
    "max_tokens": 16,
    "stream": true
  }'
```

### Audio input

Используйте только модели, у которых input_modalities содержит audio.

```bash
export AUDIO_BASE64="$(base64 -w 0 ./sample.wav)"

curl https://api.closerouter.dev/v1/chat/completions \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemini-3.1-pro-preview",
    "messages": [
      {
        "role": "user",
        "content": [
          { "type": "text", "text": "Describe this audio in one sentence." },
          {
            "type": "input_audio",
            "input_audio": {
              "data": "'"$AUDIO_BASE64"'",
              "format": "wav"
            }
          }
        ]
      }
    ],
    "max_tokens": 80
  }'
```

### Синтез речи — /audio/speech

Выберите модель с этим endpoint в каталоге. Совместим с OpenAI SDK: ответ 200 содержит готовое аудио и X-Generation-Id. Без response_format используется PCM; MP3 задаётся явно. Поддерживаемые голоса и форматы указаны у модели. Ожидание ограничено 120 секундами; при отмене или таймауте до успешного завершения списания нет. Аудио не передаётся постепенно.

```bash
curl https://api.closerouter.dev/v1/audio/speech \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"your-speech-model-id","input":"Hello!","response_format":"mp3"}' \
  --output speech.mp3
```

### Поля запроса

- model обязателен. Можно передать models как список fallback-кандидатов.
- messages принимает стандартные роли system, user и assistant.
- stream: true включайте только для моделей, где endpoint detail показывает supports_streaming: true.
- Поле user можно передать для вашей внутренней идентификации конечного пользователя.
- max_price, например {"input": 0.5, "cache_read": 0.1}, задаёт необязательные предельные цены в USD за миллион токенов. Поля запроса переопределяют модельные и общие настройки ключа; подробные правила и примеры — в разделе API Keys.

### Кэш на 20 или 120 минут

- Для Chat-маршрута с ценами записи кэша на 20 и 120 минут можно передать число cache_ttl в JSON или один числовой заголовок X-Cache-TTL. Оба значения пересылаются выбранному провайдеру без изменения.
- Без параметра действует 20 минут. Если хотя бы одно значение составляет 120 или больше, применяется тариф 120 минут; иначе — тариф 20 минут. Это правило действует и при противоречии между JSON и заголовком.
- Для такого маршрута некорректное или повторяющееся значение заголовка, а также нечисловой cache_ttl возвращает 400 до обращения к провайдеру.
- В тарифе Vokis выбранная цена записи применяется ко всем входным токенам, не прочитанным из кэша, включая новый фрагмент после кэшированного префикса. Цена чтения применяется к токенам, прочитанным из кэша. Списание по тарифу записи не означает, что провайдер подтвердил создание записи кэша.
- Другие маршруты сохраняют свои правила кэширования и тарификации; проверьте цены выбранного провайдера в каталоге моделей.

## Responses API

OpenAI-compatible Responses endpoint для текстовых сценариев.

### Responses request

```bash
curl https://api.closerouter.dev/v1/responses \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-5.4-mini",
    "input": "Reply with exactly: ok",
    "max_output_tokens": 16
  }'
```

### Важно

- Используйте POST /responses. GET /responses возвращает 405.
- Для лимита ответа используйте max_output_tokens.
- max_price задаёт необязательные input, output, cache_read и cache_write в USD за миллион токенов и работает также со streaming. Правила наследования и отказа 422 без списания описаны в разделе API Keys.
- Практический минимум max_output_tokens для OpenAI-моделей сейчас 16.

## Messages API

Anthropic-style Messages endpoint с ключом CloseRouter.

### Messages request

```bash
curl https://api.closerouter.dev/v1/messages \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-haiku-4.5",
    "max_tokens": 16,
    "messages": [
      { "role": "user", "content": "Reply with exactly: ok" }
    ]
  }'
```

### Поля запроса

- max_tokens обязателен для Messages API.
- messages принимает Anthropic-style массив сообщений.
- Для Anthropic-compatible клиентов можно использовать x-api-key.
- max_price задаёт необязательные input, output, cache_read и cache_write в USD за миллион токенов и работает также со streaming. Поля запроса переопределяют настройки ключа; правила тарифов и кеша описаны в разделе API Keys.

## Images API

Генерация и редактирование изображений для моделей с image endpoint-ами.

### Операции, цена и восстановление

- GET /media/models возвращает только включённые операции, input_schema, имена полей исходников, provider_option_id и наши ставки с единицами и условиями.
- POST /media/quote принимает model, operation, input и provider.option_id. Он не запускает модель и не списывает деньги. reserved_usd — максимальный резерв; pending означает неопределённость итоговой суммы.
- Отправьте те же поля на endpoint из метаданных и добавьте max_cost_usd из quote. Если необходимый резерв вырос, сервер вернёт 409 до запуска.
- Для multipart передавайте input как JSON-строку, а файлы — под именами input_image_fields; повторяйте имя с [] для массивов. Один файл — до 20 МБ (20 000 000 байт), не более 16 исходников; схема операции может задавать меньший предел. Общий JSON ограничен 20 МиБ, для больших исходников используйте multipart.
- Публичный HTTPS URL скачивается и проверяется до запуска. Предыдущий результат доступен только владельцу. Для операций без обязательного prompt текст не нужен.
- Резерв применяется только к этим image-операциям. Списание происходит после сохранения всех результатов у нас; остаток резерва освобождается. Все применимые позиции, включая дополнительные входы, входят в итог.
- Ответ 202 с object=image.request означает незавершённую доставку. Читайте GET /media/requests/{id}; повторный POST создаст новую генерацию. При outcome_unknown автоматического повтора нет. Безвозвратно недоставленный результат не оплачивается клиентом.
- Результаты сохраняют порядок и метки слоёв/масок. Для операций предел одного выходного файла — 64 МиБ, общий предел результатов — 256 МиБ. URL указывает только на наш ресурс; response_format=b64_json возвращает сохранённые байты.

### GPT Image generation

```bash
curl https://api.closerouter.dev/v1/images/generations \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-image-2",
    "prompt": "A minimal product photo on a white background",
    "n": 1,
    "size": "1024x1024",
    "quality": "medium"
  }'
```

### Gemini image generation

```bash
curl https://api.closerouter.dev/v1/images/generations \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemini-3-pro-image",
    "prompt": "A minimal product photo on a white background",
    "size": "1024x1024",
    "input": { "resolution": "4K" }
  }'
```

### Image edits

```
curl https://api.closerouter.dev/v1/images/edits \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -F "model=openai/gpt-image-2" \
  -F "image[]=@input.png" \
  -F "prompt=Replace the background with a clean studio backdrop"
```

### Форматы ввода

- GPT Image и Gemini image используют /images/generations и /images/edits. Gemini image недоступны на /chat/completions.
- n, size, quality, style, background, moderation, output_compression и output_format принимаются на любом image-маршруте и переводятся в схему операции. size задаёт только пропорции и пишется лишь в поле, которое ничего не тарифицирует, поэтому резерв не растёт.
- Значения конкретной операции передавайте напрямую или в input: они имеют приоритет. Разрешение Gemini Pro и Flash Preview — input.resolution 1K, 2K или 4K; google/gemini-3.1-flash-lite-image поддерживает только 1K.
- Значение вне объявленных операцией заменяется её значением по умолчанию, кроме тарифицируемого или обязательного поля: там запрос отклоняется со списком допустимых значений. Поля, которого нет ни в схеме, ни в списке выше, тоже отклоняется, и metadata называет поле и принимаемые операцией поля.
- Для edits используйте multipart image[] uploads или JSON images как inline data: URL.
- Для обычных inference inputs отправляйте файлы как data URL или multipart. Объявленные ниже image-операции также принимают публичные HTTPS URL и ссылки на ваши предыдущие результаты.

### Выдача и хранение

- Внешние результаты изображений CloseRouter перезаливает перед ответом. Ссылка контролируется CloseRouter и никогда не перенаправляет на провайдера.
- Такая ссылка доступна ровно 30 дней с момента создания; в момент истечения она становится недоступной.
- У обычных image-маршрутов b64_json остаётся inline. Новые image-операции сначала сохраняют результат, а затем при необходимости возвращают его байты в b64_json.

## Video API

Video API асинхронный: сначала создайте task, затем проверяйте статус.

### Submit and poll

```bash
curl https://api.closerouter.dev/v1/videos/submit \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/veo-3.1",
    "prompt": "A clean product shot of a futuristic API dashboard",
    "duration": 5,
    "aspect_ratio": "16:9"
  }'

curl https://api.closerouter.dev/v1/videos/tasks/{task_id} \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"
```

### Статусы

- POST /videos/submit возвращает id задачи.
- GET /videos/tasks/{task_id} возвращает status, outputs, error, model и duration_seconds.
- Используйте модель, у которой output_modalities содержит video.

## API-ключи

Server-side управление ключами аккаунта через api.closerouter.dev.

### Создать и получить список

```bash
curl https://api.closerouter.dev/v1/keys \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production worker",
    "is_anonymous": false,
    "max_price": { "input": "1", "output": "4" },
    "max_price_by_model": {
      "openai/gpt-5.4-mini": { "cache_read": "0.1" }
    },
    "spend_limit": {
      "amount_usd": "25",
      "period": "monthly"
    }
  }'

curl https://api.closerouter.dev/v1/keys \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"
```

### Лимит и отзыв

```bash
curl https://api.closerouter.dev/v1/keys/{key_id}/limit \
  -X PATCH \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "max_price": { "input": "0.5" },
    "max_price_by_model": {
      "openai/gpt-5.4-mini": { "cache_read": "0.1", "cache_write": "0.5" }
    }
  }'

curl https://api.closerouter.dev/v1/keys/{key_id}/limit \
  -X PATCH \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "spend_limit": null, "max_price": null, "max_price_by_model": {} }'

curl https://api.closerouter.dev/v1/keys/{key_id} \
  -X DELETE \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"
```

### Режим Auto ключа

- При создании в кабинете выбор Auto скрыт в «Дополнительных настройках». По умолчанию ключ наследует настройки модели и аккаунта, без Auto-подписи. В меню с тремя точками можно изменить режим существующего ключа.
- POST /keys принимает необязательное auto_strategy: "cheap" | "fast" | "stable" | null. Без поля или при null ключ наследует настройки. Явный режим сохраняется буквально, даже если совпадает с режимом аккаунта, и показывает бейдж.
- PATCH /keys/{key_id}/auto принимает {"auto_strategy":"fast"}; {"auto_strategy":null} возвращает наследование. Пропущенное или неизвестное значение даёт 400. На api.closerouter.dev требуется unrestricted API-ключ; на closerouter.dev/v1 — Dashboard JWT владельца. Настройка disabled ключа доступна через кабинет, revoked ключ — 404.
- Приоритет: явный provider/strategy запроса → ручная цепочка → Auto ключа → Auto модели → Auto аккаунта → Cheap. Явный Auto в запросе обходит ручную цепочку. Закреплённый Auto ключа цепочку не обходит. Смена режима действует на новые запросы; текущие attempts/fallback сохраняют прежний план.
- GET /providers и ответ PATCH /providers добавляют effective_auto_strategy и auto_strategy_source для текущего ключа; источник api_key означает закрепление. При ручной цепочке оба поля null. auto_strategy и auto_strategy_override сохраняют смысл настроек аккаунта и модели. PATCH /providers меняет настройку модели аккаунта, а не ключа. Справочные цены /models не меняются.

### Ограничить доступ к моделям

Удобнее выбрать модели в кабинете на странице ключей. REST-изменение доступно только с Dashboard JWT на closerouter.dev; обычный API-ключ не может расширить себе или соседнему ключу доступ.

```bash
export CLOSEROUTER_DASHBOARD_TOKEN="your_dashboard_access_token"

curl https://closerouter.dev/v1/keys/{key_id}/model-access \
  -X PATCH \
  -H "Authorization: Bearer $CLOSEROUTER_DASHBOARD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model_access": {
      "type": "allowlist",
      "model_ids": [
        "anthropic/claude-haiku-4.5",
        "openai/gpt-5.4-mini"
      ]
    }
  }'

curl https://closerouter.dev/v1/keys/{key_id}/model-access \
  -X PATCH \
  -H "Authorization: Bearer $CLOSEROUTER_DASHBOARD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "model_access": { "type": "all" } }'
```

### Доступ к моделям

- Новые и существующие ключи по умолчанию имеют model_access.type = "all".
- allowlist принимает от 1 до 100 уникальных публичных ID моделей и атомарно заменяет предыдущий список; aliases сохраняются как канонические ID.
- Если хотя бы одна модель из model и models[] запрещена, весь inference-запрос отклоняется с 403 api_key_model_access_denied до provider-вызова, usage и списания.
- Ограниченный ключ может читать GET /keys, но не может создавать, изменять или отзывать ключи: API возвращает 403 api_key_management_forbidden.

### Spend limits

- spend_limit.amount_usd задается строкой в USD.
- period может быть daily, weekly или monthly.
- Передайте spend_limit: null, чтобы очистить лимит.
- DELETE /keys/{key_id} отзывает ключ; новые запросы с ним прекращаются сразу.

### Максимальные цены текстовых моделей

- На странице /keys откройте «Лимиты ключа» и включите максимальную цену. Задайте общие лимиты или добавьте несколько моделей через поиск. Меняйте выбранные поля сразу у нескольких моделей, раскрывайте строки для отдельных значений и наследования. Кнопка «Сохранить» сохраняет все изменения, включая ещё не применённые к выбранным моделям. Цена и бюджет расходов настраиваются независимо.
- POST /keys, GET /keys и PATCH /keys/{key_id}/limit используют max_price для общих настроек и max_price_by_model для объекта {"Model ID": {"input": "1"}}. До 100 моделей; aliases сохраняются как канонические публичные Model ID.
- input, output, cache_read и cache_write необязательны: строки или числа в USD за миллион токенов, от 0, до 8 знаков после точки и 12 цифр до точки. Ноль — реальный нулевой предел; пустой объект не задаёт ограничений.
- Приоритет каждого поля: значение запроса → настройка конкретной модели на ключе → общая настройка ключа → без ограничения. Override может как повысить, так и снизить предел; пропущенные поля наследуются.
- При PATCH пропущенные верхние поля сохраняются. Переданный max_price полностью заменяет общие поля, а max_price_by_model — весь список моделей и их поля. max_price: null очищает общие настройки; max_price_by_model: {} или null очищает модельные. Для удаления одного поля или модели передайте полный оставшийся объект. Изменение только цен сохраняет spend_limit, и наоборот.
- В /chat/completions, /responses и /messages передайте, например, "max_price": {"input": 0.5, "cache_read": 0.1}. Это работает для обычных и потоковых запросов, Auto, явного провайдера и разрешённых запасных попыток; поле не передаётся поставщику.
- Сравниваются максимальные клиентские ставки по базовому тарифу и всем ступеням контекста. Для cache_write берётся кратчайший доступный TTL, а не самая низкая цена: длинный TTL в запросе может оплачиваться выше этого предела. Если отдельных цен кеша нет, применяется обычная ставка входа. Подтверждённая бесплатная акция учитывается как $0; без неё действует обычный тариф.
- Цена, равная пределу, допускается. Если ни один доступный маршрут не подходит, API возвращает 422 max_price_no_route до вызова поставщика, без списания. Неверный объект или цена дают 400 invalid_request. Эти настройки относятся только к текстовым моделям.

## Стоимость запросов и баланс

Получайте итоговую стоимость сразу в inference-ответе или запрашивайте сохранённый результат по request ID.

### Стоимость в inference-ответе

```json
{
  "usage": {
    "prompt_tokens": 120,
    "completion_tokens": 30,
    "total_tokens": 150,
    "cost": 0.000123
  }
}
```

### usage.cost

- Успешные Chat Completions, Responses и Messages запросы возвращают итоговую стоимость запроса в USD в числовом поле usage.cost.
- В обычном JSON-ответе поле находится в usage; в streaming-ответе оно приходит в финальном usage-событии соответствующего API.
- Это итоговое списание CloseRouter после завершения биллинга, а не предварительная оценка или внутренняя цена провайдера.

### Получить запрос по request ID

Возьмите request ID из заголовка x-closerouter-request-id inference-ответа и подставьте его в URL. Не используйте для lookup верхнеуровневое поле id из тела ответа.

```bash
export REQUEST_ID="00000000-0000-0000-0000-000000000000"

curl https://api.closerouter.dev/v1/requests/$REQUEST_ID \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"
```

### Ответ lookup

```json
{
  "data": {
    "request_id": "00000000-0000-0000-0000-000000000000",
    "external_user": null,
    "status": "completed",
    "model": "openai/gpt-5.4-mini",
    "api_type": "chat",
    "provider": "Provider 7",
    "api_key_id": "11111111-1111-4111-8111-111111111111",
    "streaming": false,
    "latency_ms": 934,
    "usage": {
      "prompt_tokens": 120,
      "completion_tokens": 30,
      "total_tokens": 150,
      "cache_creation_tokens": 0,
      "cache_read_tokens": 0,
      "cost": 0.000123
    },
    "created_at": "2026-08-21T10:00:00.000Z",
    "completed_at": "2026-08-21T10:00:01.000Z"
  }
}
```

### GET /requests/{request_id}

- Endpoint возвращает status, model, api_type, токены, cache-токены, usage.cost и временные метки одного запроса.
- Любой активный API-ключ аккаунта может получить запрос, созданный другим ключом того же аккаунта.
- Для запроса в обработке usage равен null. Завершённые запросы имеют status completed, partial или failed; partial может содержать стоимость уже переданных данных.
- Чужой, отсутствующий или некорректный request ID возвращает 404.

### Список последних запросов

Возвращает запросы аккаунта в порядке от новых к старым. limit от 1 до 100 (по умолчанию 20), постраничность через offset, has_more показывает, есть ли ещё страница. Доступны фильтры start_date, end_date, model, status и user.

```bash
curl -G https://api.closerouter.dev/v1/requests \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  --data-urlencode "limit=20" \
  --data-urlencode "status=failed"
```

### Статистика за период

Без дат берутся последние 30 дней; период не может быть больше 366 дней. group_by можно повторять, чтобы считать только нужные разрезы.

```bash
curl -G https://api.closerouter.dev/v1/usage \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY" \
  --data-urlencode "start_date=2026-08-01" \
  --data-urlencode "end_date=2026-08-31" \
  --data-urlencode "group_by=day" \
  --data-urlencode "group_by=model"
```

### Ответ статистики

```json
{
  "data": {
    "period": {
      "start": "2026-08-01T00:00:00.000Z",
      "end": "2026-08-31T23:59:59.999Z",
      "timezone": "UTC"
    },
    "totals": {
      "requests": 1840,
      "failed_requests": 12,
      "prompt_tokens": 4210000,
      "completion_tokens": 980000,
      "cache_creation_tokens": 120000,
      "cache_read_tokens": 3100000,
      "total_tokens": 5190000,
      "cost": 12.4712
    },
    "by_day": [
      { "date": "2026-08-01", "requests": 64, "total_tokens": 180400, "cost": 0.4312 }
    ],
    "by_model": [
      { "model": "openai/gpt-5.4-mini", "requests": 1200, "total_tokens": 3400000, "cost": 8.1204 }
    ],
    "by_provider": [
      { "provider": "Provider 7", "requests": 1180, "cost": 7.9902 }
    ],
    "by_api_key": [
      { "api_key_id": "1111...", "api_key_name": "Production", "cost": 11.2 }
    ],
    "by_api_type": [{ "api_type": "chat", "cost": 10.9 }],
    "by_status": [{ "status": "success", "requests": 1828 }]
  }
}
```

### GET /usage

- totals и каждая строка разреза содержат requests, failed_requests, prompt_tokens, completion_tokens, cache_creation_tokens, cache_read_tokens, total_tokens и списанную стоимость cost.
- Доступные разрезы group_by: day, model, provider, api_key, api_type, status. Без параметра возвращаются все; невыбранные приходят пустыми массивами.
- Фильтры start_date, end_date, model (можно повторять), api_key_id и timezone сужают период.
- Разрезы отсортированы по стоимости, кроме by_day — он идёт по датам.
- Статистика охватывает все расходы аккаунта, включая дашборд и Telegram, поэтому сходится со страницей Usage в дашборде.
- Провайдер называется тем же публичным именем, которое inference-ответы возвращают в поле provider.

### Credits

```bash
curl https://api.closerouter.dev/v1/credits \
  -H "Authorization: Bearer $CLOSEROUTER_API_KEY"
```

### Ответ

- total_credits: текущий доступный баланс.
- total_usage: суммарное списание за использование API.
- Для платной модели при недостаточном балансе API возвращает 402 insufficient_balance.
- Явно бесплатный запрос сохраняет обычную запись использования с нулевой стоимостью и не создает списание.

## Ошибки

Все ошибки возвращаются в одном JSON-формате.

### Error JSON

```json
{
  "error": {
    "code": "invalid_request",
    "message": "Request body must be a JSON object",
    "status": 400,
    "metadata": {
      "request_id": "..."
    }
  }
}
```

### Частые коды

- 400 invalid_request: неверный JSON, отсутствует model, неподдерживаемый параметр или смешаны бесплатные и платные fallback-модели.
- 401 invalid_api_key: нет ключа или ключ неверный.
- 402 insufficient_balance: недостаточно средств.
- 403 telegram_link_required: привяжите Telegram на /settings перед использованием бесплатной модели.
- 429 rate_limited: лимит запросов временно исчерпан; для дневного лимита бесплатных моделей metadata.limit_type = free_models_daily_requests, а Retry-After показывает секунды до полуночи UTC.
- 429 rate_limited: для моделей, которые оплачивает акция Happy Hour, metadata.limit_type = happy_hour_requests_per_minute и действует отдельный минутный лимит на пользователя.
- 503 no_available_provider: для выбранной модели и endpoint сейчас нет доступного маршрута.
- 503 service_unavailable: проверка доступа к бесплатной модели временно недоступна и запрос отклонен без вызова провайдера.
- metadata.request_id пригодится при обращении в поддержку.
