# XAnnotations
Additional [active annotations](https://eclipse.org/xtend/documentation/204_activeannotations.html) for the [Java-dialect Xtend](https://eclipse.org/xtend)

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