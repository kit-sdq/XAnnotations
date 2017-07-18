# XAnnotations
Additional [active annotations](https://eclipse.org/xtend/documentation/204_activeannotations.html) for the [Java-dialect Xtend](https://eclipse.org/xtend)

Install from [nightly update site](https://kit-sdq.github.io/updatesite/nightly/xannotations) (only for use via "Install Software" in Eclipse)

## @StaticDelegate
Use the [active annotation @StaticDelegate](https://github.com/kit-sdq/XAnnotations/blob/master/bundles/edu.kit.ipd.sdq.activextendannotations/src/edu/kit/ipd/sdq/activextendannotations/StaticDelegate.xtend)  in an Xtend class to automatically obtain delegation methods for all accessible static methods of other classes. 

@StaticDelegate can be used, for example, in order to reduce the number of imports for [static extension methods](https://eclipse.org/xtend/documentation/202_xtend_classes_members.html#extension-imports), which allow you to call static methods that take at least one parameter as if the were declared as local methods of the first parameter.

An example usage of @StaticDelegate can be found in the [API for OCL-aligned extension methods](https://github.com/kit-sdq/XOCL/blob/master/bundles/edu.kit.ipd.sdq.xocl.extensions/src/edu/kit/ipd/sdq/xocl/extensions/XOCLExtensionsAPI.xtend).

```Xtend
import edu.kit.ipd.sdq.activextendannotations.StaticDelegate

@StaticDelegate(#[BooleanXOCLExtensions,ClassXOCLExtensions,...])
class XOCLExtensionsAPI {
  ...
}
```

## @Lazy

[`@Lazy`](https://github.com/kit-sdq/XAnnotations/blob/master/bundles/edu.kit.ipd.sdq.activextendannotations/src/edu/kit/ipd/sdq/activextendannotations/Lazy.xtend) can be declared on fields in order to initialise them lazily. That means that their initialiser code will not be executed before its first access:

```xtend
class Example {
	@Lazy String field = expensiveComputation()
	
	def expensiveComputation() {
		// will not be called before the first access of field
	}
}
``` 

To realise this behaviour, a getter `getField` will be generated through which the field will be accessed. `field` will be renamed to `_field` and should not be accessed directly. For more information, see [the annotation’s documentation](https://github.com/kit-sdq/XAnnotations/blob/master/bundles/edu.kit.ipd.sdq.activextendannotations/src/edu/kit/ipd/sdq/activextendannotations/Lazy.xtend).

## @Utility

[`@Utility`](https://github.com/kit-sdq/XAnnotations/blob/master/bundles/edu.kit.ipd.sdq.activextendannotations/src/edu/kit/ipd/sdq/activextendannotations/Utility.xtend) can be declared on classes to make them Utility classes. This means that they:

 * are `final`
 * only have one private, parameterless constructor that does nothing
 * may only have `static` methods
 * may have no fields but `static final` ones
 
This annotation is meant to save some keystrokes, but to make Utility classes easier to detect.

## @DelegateDeclared
[`@DelegateDeclared`](https://github.com/kit-sdq/XAnnotations/blob/master/bundles/edu.kit.ipd.sdq.activextendannotations/src/edu/kit/ipd/sdq/activextendannotations/DelegateDeclared.xtend) is a variant of the Xtend @Delegate active annotation that only delegates members that are declared in the interfaces which are implemented directly by the class that uses this annotation.

For example, when delegating methods from an interface, only the methods declared in that interface are delegated. The methods that are declared in other interfaces which this interface extends are not delegated.