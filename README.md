
# Data Processing with Streams and Pipelines in Ruby

This is a brief exploration of using Ruby to work with [streams and pipelines](https://en.wikipedia.org/wiki/Stream_%28computing%29) for processing data.

You've already used these concepts if you've ever done anything like this in a shell:

```bash
# find all usernames with "robert", sort them, and display a count
grep "robert" usernames.txt | sort | wc -l
```

The usefulness of this model is best understood in contrast to the "ad-hoc" way in which data processing scripts are often written. Such scripts have the following problems:

- they often load entire sets of data into memory at once, which isn't scalable to large data sets
- they iterate multiple times over data, which is inefficient
- complex interrelationships among its parts force you to understand everything, rather than being able to isolate pieces; this is hard to maintain
- they are difficult to parallelize to improve run times

Because streams and pipelines work sequentially, they address these issues:

- only one record at a time is loaded into memory (usually)
- data passes through the pipeline only once, which is simple to understand
- pipelines make it easier to grasp the data flow and troubleshoot isolated parts without needing to understand everything
- easier to parallelize (at least for operations that don't involve state)

## A Simple Example

Here's a super simple example of typical iteration in Ruby. We start with a range of numbers from 1 to 5, add 10 to each one, filtering on even ones, and printing the results.

```ruby
(1..5).map { |i|
  puts "adding 10 to #{i}"
  i + 10
}.
  select { |i|
  puts "filtering #{i} on evenness"
  i % 2 == 0
}.
  each { |i|
  puts "in each: #{i}"
}
```

The output:

```
adding 10 to 1
adding 10 to 2
adding 10 to 3
adding 10 to 4
adding 10 to 5
filtering 11 on evenness
filtering 12 on evenness
filtering 13 on evenness
filtering 14 on evenness
filtering 15 on evenness
in each: 12
in each: 14
```

No surprises here. All the data is processed with each method call. `#map` produces a 5-item Array in memory. `#select` produces a 2-item Array in memory. Then `#each` iterates over that 2-item Array to print out the values.

Now here's the same program using a stream of objects. The single difference from the code above is the `#lazy` method added to the beginning of the method call chain (we'll explain this below).

```ruby
(1..5).lazy.map { |i|
  puts "adding 10 to #{i}"
  i + 10
}.
  select { |i|
  puts "filtering #{i} on evenness"
  i % 2 == 0
}.
  each { |i|
  puts "in each: #{i}"
}
```

Now the output is different:

```
adding 10 to 1
filtering 11 on evenness
adding 10 to 2
filtering 12 on evenness
in each: 12
adding 10 to 3
filtering 13 on evenness
adding 10 to 4
filtering 14 on evenness
in each: 14
adding 10 to 5
filtering 15 on evenness
```

`(1..5).lazy` doesn't return a data structure, but a stream of integers. Each one is processed one at a time through the pipeline. This means we are never storing more than one integer in memory at a time. There are no immediate data structures, such as Arrays, that are generated; only a "chain" of lazy enumerables that comprise the stream.

In non-trivial cases involving large sets of data and lots of operations, streams are better at optimizing for both space and time: they minimize the amount of memory used, and make it easy to parallelize operations for faster performance.

## Enumerables, Laziness, Force, and Enumerators

In a nutshell, lazy `Enumerable`s are how Ruby lets us handle streams of data and write pipelines for processing them.

Ruby's `Enumerable` module is used everywhere in the stdlib where you need to enumerate things. The only requirement for a class to be an `Enumerable` is that it should implement `#each`. An `Enumerable` provides a LOT of operations on top of `#each`, including:

- `map/collect`: to transform or mutate-in-place items
- `select/reject`: filter items
- `cycle`: calls a block N times, for each item
- `drop`: drops first N items, returning the rest
- `drop_while`: drops elements up to 1st item for which block is true,
  returning the rest
- `take`: returns first N items
- `take_while`: returns elements until block is false for an item
- `zip`: zip together items from passed-in args
- `inject/reduce` (a.k.a. fold): combines elements, storing result in an
  accumulator
- and a bunch more...

Lazy enumerables were added in Ruby 2.0.0. There is an `Enumerable::Lazy` module, and `Enumerable` has a `#lazy` method to make an existing `Enumerable` instance into a lazy one. This makes enumerables behave like streams. Unlike most non-lazy enumerables, a stream can only be consumed ONCE. Many of the above operations on an `Enumerable::Lazy` object return an `Enumerable::Lazy` object in turn, making it possible to chain operations together to construct a pipeline.

Additionally, you can use the `Enumerator` and `Enumerator::Lazy` classes to create enumerables on-the-fly.

Laziness means that these enumerables don't do anything when they are constructed. They have to be evaluated, either by calling the `#force` method, or using one of the methods that forces evaluation, such as `#each`. An important consideration: if evaluating a lazy enumerable results in a large array, it will take up a lot of memory, so be careful. Most of the time, you should probably use `#each` instead at the end of the pipeline, and deal with each object one at a time (usually storing it to a file or database, or printing it to stdout).

## Real World Complexity

But not every complex data processing problem can be expressed in terms of a single pipeline.

Splitting and merging: `Enumerable` doesn't support splitting (i.e. teeing) and merging out of the box. You need to roll your own solution or find a gem to do this.

Storing results: You might have to write the result of a pipeline to a file, before using that data in another pipeline. For example, you need to do this when using the results in several places in another pipeline.

Stateful operations: Operations may also need to store state in auxiliary objects. For example, an operation that counts the number of records that fall into various buckets would store that information outside the stream.

## Organizing Code

You can imagine abstracting data sources, individual operations, and entire pipelines.

Data sources can be a database, a flat text file, a CSV file, and even an XML file. Laziness can be achieved by reading one line or record at a time from a file, or fetching one record at a time from a database resultset.

It's possible to build a library of reusable, composable operations for the data you're working with. This also makes the operations easier to understand, unit-test, troubleshoot, since they are highly compartmentalized.

Treating an entire pipeline as an abstraction, similar to how you might use a script file to store piped-together UNIX commands, would allow you to make certain parameters configurable.

## Performance

Compared to an equivalent iterative solution, using lazy enumerables is known to be somewhat slower in Ruby. How much slower seems to depend on what the actual pipeline looks like. This is offset by the fact that you can easily parallelize operations. Even without parallelization, this shouldn't be a problem, but it's something to keep in mind.

## Questions

How to design a data processing system with dependencies among streams and pipelines?

Is there a need for some kind of framework, or are these patterns enough?

## Non-Ruby options

One of the major drawbacks to Ruby (in my opinion) is the lack of type checking. Java and Scala are two languages that are better at this, though arguably, development is slower using them.

Java 8 added a [Streams API](http://www.oracle.com/technetwork/articles/java/ma14-java-se-8-streams-2177646.html) and lambda expressions, which make it possible to write code that looks a lot like the Ruby code above. You get all the pros and cons of Java and the JVM.

```java
int[] x = new int[] { 1,2,3,4,5 };
Arrays.stream(x)
    .map(i -> {
            System.out.println("adding 10 to " + i);
            return i + 10;
        })
    .filter(i -> {
            System.out.println("filtering " + i + " on evenness");
            return i % 2 == 0;
        })
    .forEach(i -> {
            System.out.println("in each: " + i);
        });
```

Scala is a popular language used for "big data" because it's supported by Apache Spark. A mix of object-oriented and functional programming models, Scala has strong support for streams and concurrency. It interoperates with Java and runs on the JVM, but is less verbose. The learning curve is steep.

```scala
val x = Array(1,2,3,4,5)
x.toStream.map(i => {
  println("adding 10 to " + i)
  i + 10
}).filter(i => {
  println("filtering " + i + " on evenness")
  i % 2 == 0
}).foreach(i => println("in each: " + i))
```

## More Information

[Blog post by original author of the Enumerable::Lazy code](http://railsware.com/blog//2012/03/13/ruby-2-0-enumerablelazy/)

[Example of using Enumerators to process a large file](http://blog.honeybadger.io/using-lazy-enumerators-to-work-with-large-files-in-ruby/)

[Excellent explanation of how Enumerable::Lazy works under the hood](http://patshaughnessy.net/2013/4/3/ruby-2-0-works-hard-so-you-can-be-lazy)

[Discussion of a complex use of streams in Python and bash, including tee and merge operations](http://wordaligned.org/articles/python-streams-vs-unix-pipes)
