# Stasks
Stasks is CLI Simple Private Task Manager beta

個人用のCLIなシンプルなタスクマネージャ
とりあえず最低限な動作だけ

# Command
## Add feature
```
$ ./stasks.rb -a -k feature -t 'AAA'

$ ./stasks.rb -v
# feature list...
-- 1: {:text=>"AAA"}

# task list...
- wait list...

- ready list...

- doing list...

- done list...
```

## Add task
featureのidが1(つまりfeature)のタスクを登録。
point(-p)はまだ無意味
```
$ ./stasks.rb -a -k task -b 1 -p 1 -t 'AAA task1'

$ ./stasks.rb -v
# feature list...
-- 1: {:text=>"AAA"}

# task list...
- wait list...
-- 1: {:belong=>"1", :point=>10, :text=>"AAA task1"}

- ready list...

- doing list...

- done list...

```

これでwaitなtaskに追加

## ready to task
readyにする

```
$ ./stasks.rb -r -i 1
# feature list...
-- 1: {:text=>"AAA"}

# task list...
- wait list...

- ready list...
-- 1: {:belong=>"1", :point=>10, :text=>"AAA task1"}

- doing list...

- done list...

```

## start to task
```
$ ./stasks.rb -s -i 1
# feature list...
-- 1: {:text=>"AAA"}
-- 2: {:text=>"BBB"}

# task list...
- wait list...

- ready list...

- doing list...
-- 1: {:belong=>"1", :point=>10, :text=>"AAA task1"}

- done list...

```

## finish to task
```
$ ./stasks.rb -f -i 1
# feature list...
-- 1: {:text=>"AAA"}
-- 2: {:text=>"BBB"}

# task list...
- wait list...

- ready list...

- doing list...

- done list...
-- 1: {:belong=>"1", :point=>10, :text=>"AAA task1"}

```
