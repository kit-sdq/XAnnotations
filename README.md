# XAnnotations
Additional [active annotations](https://eclipse.org/xtend/documentation/204_activeannotations.html) for the [Java-dialect Xtend](https://eclipse.org/xtend)

## @StaticDelegate
Use this active annotation in an Xtend class to automatically obtain delegation methods for all non-private static methods of other classes. These other classes are specified as an annotation value called delegation targets. 

@StaticDelegate can be used, for example, in order to reduce the number of imports for [static extension methods](https://eclipse.org/xtend/documentation/202_xtend_classes_members.html#extension-imports), which allow you to call static methods that take at least one parameter as if the were declared as local methods of the first parameter.
