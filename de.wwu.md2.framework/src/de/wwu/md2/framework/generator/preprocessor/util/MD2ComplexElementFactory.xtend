package de.wwu.md2.framework.generator.preprocessor.util

import de.wwu.md2.framework.mD2.Attribute
import de.wwu.md2.framework.mD2.AttributeType
import de.wwu.md2.framework.mD2.ContentProvider
import de.wwu.md2.framework.mD2.Entity
import de.wwu.md2.framework.mD2.PathTail
import de.wwu.md2.framework.mD2.impl.MD2FactoryImpl
import java.util.regex.Pattern
import org.eclipse.xtext.xbase.lib.Pair

import static extension org.eclipse.emf.ecore.util.EcoreUtil.*

/**
 * Helper factory class that creates complex/compound MD2 elements. E.g. creates and configures a
 * contentProvider for a given entity or creates an entity with a given list of attributes.
 * 
 * It also inherits from the actual MD2Factory implementation generated by Xtext, so that all basic
 * createXXX methods are available as well. All factory methods for compound elements are prefixed with
 * Complex, i.e. createComplexXXX.
 */
class MD2ComplexElementFactory extends MD2FactoryImpl {
	
	def MD2ComplexElementFactory() {
		super
	}
	
	/**
	 * Creates an entity with the given name and a set of attributes. Each attribute is defined by a pair
	 * with the attribute name as the key and the attribute type (Xtend syntax: "nameString"->attributeType).
	 * The attribute types are implicitly copied, so that the same instance can be reused in the attributes definition.
	 * 
	 * @param name - Name of the entity.
	 * @param attributes - Arbitrary number of pairs with the attribute name as the key and the attribute type.
	 */
	def createComplexEntity(String name, Pair<String, AttributeType>... attributes) {
		val entity = this.createEntity
		entity.setName(name)
		
		for (attr : attributes) {
			val attribute = this.createAttribute
			attribute.setName(attr.key)
			attribute.setType(attr.value.copy)
			entity.attributes.add(attribute)
		}
		
		return entity
	}
	
	/**
	 * Creates a content provider for a given entity.
	 * 
	 * @param entity - The entity for which the content provider is created.
	 * @param name - Name of the content provider. Suggestion: __entityNameProvider.
	 * @param isLocal - Defines whether it is a local (true) or a remote (false) content provider.
	 * @param isReadonly - Specifies whether the content provider is read-only, i.e. data cannot be set via mappings or setters in the controller.
	 */
	def createComplexContentProvider(Entity entity, String name, boolean isLocal, boolean isReadonly) {
		val referencedModelType = this.createReferencedModelType
		referencedModelType.setEntity(entity)
		
		val contentProvider = this.createContentProvider
		contentProvider.setName(name)
		contentProvider.setType(referencedModelType)
		contentProvider.setLocal(isLocal)
		contentProvider.setReadonly(isReadonly)
		
		return contentProvider
	}
	
	/**
	 * Creates a recursively defined linked list. An entity with the given attributes and the given Name is created. The entity is enriched with
	 * an extra attribute <code>tail</code> that references another instance of the given list. Furthermore, a content provider is created. The
	 * content provider's name is derived from the entity name. E.g., given the entity name <i>__ExampleList</i>, a corresponding content provider
	 * <i>__exmapleListProvider</i> is created.
	 * 
	 * The return value is a map with key-value pairs of the form {<"entity", Entity>, <"contentProvider", ContentProvider>}.
	 * 
	 * @param name - Name of the entity.
	 * @param attributes - Arbitrary number of pairs with the attribute name as the key and the attribute type.
	 * @return A map with key-value pairs of the form {<"entity", Entity>, <"contentProvider", ContentProvider>}.
	 */
	def createComplexRecursiveList(String name, Pair<String, AttributeType>... attributes) {
		
		val entity = this.createComplexEntity(name, attributes)
		
		// add tail attribute
		{
			val attribute = this.createAttribute
			val type = this.createReferencedType
			type.setEntity(entity)
			attribute.setName("tail")
			attribute.setType(type)
			entity.attributes.add(attribute)
		}
		
		// change first character that is no underscore to lower case
		val pattern = Pattern.compile("[^_]")
		val matcher = pattern.matcher(name)
		val contentProviderName = matcher.replaceFirst(name.substring(matcher.start, matcher.start + matcher.end).toLowerCase) + "Provider"
		val contentProvider = this.createComplexContentProvider(entity, contentProviderName, true, false)
		
		return newHashMap("entity"->entity, "contentProvider"->contentProvider)
	}
	
	/**
	 * Calls <code>createComplexRecursiveList</code>. Furthermore, two SetTasks to add an element to the head of the list and to
	 * remove the first element, are built.
	 * 
	 * <p>
	 *   addToHead: <code>:contentProvider.tail = :contentProvider</code><br>
	 *   removeHead: <code>:contentProvider = :contentProvider.tail</code>
	 * </p>
	 * 
	 * @param name - Name of the entity.
	 * @param attributes - Arbitrary number of pairs with the attribute name as the key and the attribute type.
	 * @return A set with key-value pairs of the form {<"entity", Entity>, <"contentProvider", ContentProvider>,
	 *         <"addToHeadTask", AttributeSetTask>, , <"removeHeadTask", ContentProviderSetTask>}.
	 */
	def createComplexStack(String name, Pair<String, AttributeType>... attributes) {
		val md2list = createComplexRecursiveList(name, attributes)
		val contentProvider = md2list.get("contentProvider") as ContentProvider
		val entity = md2list.get("entity") as Entity
		
		// construct addToHeadTask
		{
			val addToHeadTask = this.createAttributeSetTask
			
			val tailAttribute = entity.attributes.findFirst[ a | a.name.equals("tail")]
			val pathDefinition = this.createComplexContentProviderPathDefinition(contentProvider, tailAttribute)
			addToHeadTask.setPathDefinition(pathDefinition)
			
			val contentProviderReference = this.createContentProviderReference
			contentProviderReference.setContentProvider(contentProvider)
			addToHeadTask.setSourceContentProvider(contentProviderReference)
			
			md2list.put("addToHeadTask", addToHeadTask)
		}
		
		// construct removeHeadTask
		{
			val removeHeadTask = this.createContentProviderSetTask
			
			val contentProviderReference = this.createContentProviderReference
			contentProviderReference.setContentProvider(contentProvider)
			removeHeadTask.setTargetContentProvider(contentProviderReference)
			
			val tailAttribute = entity.attributes.findFirst[ a | a.name.equals("tail")]
			val pathDefinition = this.createComplexContentProviderPathDefinition(contentProvider, tailAttribute)
			removeHeadTask.setNewValue(pathDefinition)
			
			md2list.put("removeHeadTask", removeHeadTask)
		}
		
		return md2list
	}
	
	/**
	 * Creates a ContentProviderPathDefinition for a given content provider and a list of attributes that describe the tail.
	 * i.e., <code>contentProvider.attribute1.attribute2...attributeN</code>
	 * 
	 * @param contentProvider - ContentProvider of the path definition.
	 * @param attributes - A list of attributes to construct the tail.
	 */
	def createComplexContentProviderPathDefinition(ContentProvider contentProvider, Attribute... attributes) {
		
		// construct tail
		var PathTail lastTailSegement = null
		for (attribute : attributes.reverse) {
			val tail = this.createPathTail
			tail.setAttributeRef(attribute)
			tail.setTail(lastTailSegement)
			lastTailSegement = tail
		}
		
		val pathDefinition = this.createContentProviderPathDefinition
		pathDefinition.setContentProviderRef(contentProvider)
		pathDefinition.setTail(lastTailSegement)
		
		return pathDefinition
	}
}
