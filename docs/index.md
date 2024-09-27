# libc

a standard C library for Mojo programming language.


## package build

```bash
magic run mojo package  src/libc/ -o libc.mojopkg
```
or 

```bash
make package
```

## test

```bash
magic run test 
```

or 

```bash
make test
```

## version

version 0.1.0



## external_call

```mojo
external_call[callee: StringLiteral, type: AnyTrivialRegType, *types: AnyType](*arguments: *types) -> $1

```

调用外部函数。

Parameters:

- callee: 外部函数的名称。

- type: 返回类型。

- *types: 参数类型。



Args:

- arguments(*types): 传递给外部函数的参数。

Returns：

    外部调用结果。


## `AnyType` 和 `AnyTrivialRegType`的比较

属于元类型，即类型的类型。

`AnyType`代表任何Mojo类型。 Mojo将`AnyType`类型视为一种特殊的trait。


`AnyTrivialRegType`是一种元类型，表示任何标记为可注册的 Mojo 类型。

