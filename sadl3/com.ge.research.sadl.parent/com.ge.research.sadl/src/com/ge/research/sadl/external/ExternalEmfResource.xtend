/************************************************************************
 * Copyright © 2007-2017 - General Electric Company, All Rights Reserved
 * 
 * Project: SADL
 * 
 * Description: The Semantic Application Design Language (SADL) is a
 * language for building semantic models and expressing rules that
 * capture additional domain knowledge. The SADL-IDE (integrated
 * development environment) is a set of Eclipse plug-ins that
 * support the editing and testing of semantic models using the
 * SADL language.
 * 
 * This software is distributed "AS-IS" without ANY WARRANTIES
 * and licensed under the Eclipse Public License - v 1.0
 * which is available at http://www.eclipse.org/org/documents/epl-v10.php
 * 
 ***********************************************************************/
package com.ge.research.sadl.external

import com.ge.research.sadl.builder.ConfigurationManagerForIDE
import com.ge.research.sadl.model.OntConceptType
import com.ge.research.sadl.reasoner.ConfigurationManager
import com.ge.research.sadl.sADL.SADLFactory
import com.ge.research.sadl.sADL.SadlModel
import com.ge.research.sadl.utils.ResourceManager
import com.google.inject.Inject
import com.google.inject.Injector
import com.hp.hpl.jena.ontology.AnnotationProperty
import com.hp.hpl.jena.ontology.DatatypeProperty
import com.hp.hpl.jena.ontology.Individual
import com.hp.hpl.jena.ontology.ObjectProperty
import com.hp.hpl.jena.ontology.OntClass
import com.hp.hpl.jena.ontology.OntModel
import com.hp.hpl.jena.ontology.OntModelSpec
import com.hp.hpl.jena.ontology.OntResource
import com.hp.hpl.jena.rdf.model.ModelFactory
import com.hp.hpl.jena.rdf.model.Property
import com.hp.hpl.jena.rdf.model.Resource
import com.hp.hpl.jena.util.iterator.ExtendedIterator
import com.hp.hpl.jena.vocabulary.OWL
import com.hp.hpl.jena.vocabulary.RDF
import com.hp.hpl.jena.vocabulary.RDFS
import java.io.IOException
import java.io.InputStream
import java.util.Collection
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.impl.ResourceFactoryImpl
import org.eclipse.emf.ecore.resource.impl.ResourceImpl
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.Delegate
import org.eclipse.xtext.generator.GeneratorDelegate
import org.eclipse.xtext.resource.IResourceServiceProvider
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.util.Files
import org.eclipse.xtext.util.StringInputStream
import org.eclipse.xtext.util.internal.EmfAdaptable
import org.eclipse.xtext.util.internal.Log
import org.eclipse.xtext.validation.IResourceValidator

import static com.ge.research.sadl.builder.ConfigurationManagerForIdeFactory.*
import static org.eclipse.emf.common.util.URI.createURI

@Log
class ExternalEmfResource extends ResourceImpl {

	val Map<String, SadlModel> modelMapping = newHashMap();
	
	@Accessors(PACKAGE_SETTER)
	var Injector injector;

	@Accessors(PUBLIC_GETTER)
	OntModel ontModel;

	override public void load(Map<?, ?> options) throws IOException {
		try {
			super.load(options);
		} catch (Exception e) {
			LOG.error('''Error occurred while loading the resource. URI:«uri»''', e);
		}
	}

	override protected doLoad(InputStream inputStream, Map<?, ?> options) throws IOException {
		val content = Files.readStreamIntoString(inputStream);
		ontModel = initOntModel(content);
		val baseUri = ontModel.getBaseUri(content);
		val altBaseUri = baseUri.altBaseUri;
		ontModel.listSubjects.filter[URIResource].map[it -> createURI(URI)].filter[key.localName == value.fragment].
			forEach [
				val model = getOrCreateSadlModel(altBaseUri);
				model.elements += createSadlResource(key);
			];

		ontModel.listOntologies.forEach [ ontology |
			ontology.listImports.forEach [ ontologyImport |
				val model = getOrCreateSadlModel(altBaseUri);
				model.imports += createSadlImport(model, ontologyImport);
			];
		];
	}

	override protected doUnload() {
		ontModel = null;
		modelMapping.clear();
		super.doUnload();
	}

	/**
	 * Returns with the configuration manager based on the URI of the current external EMF resource.
	 */
	protected def getConfigurationManager(Map<?, ?> options) {
		if (ResourceManager.isSyntheticUri(null, URI)) {
			return getConfigurationManagerForIDE(null, ConfigurationManager.RDF_XML_ABBREV_FORMAT, true);			 
		}
		val modelFolderUri = getModelFolderUri(URI, options);
		val modelFolderPath = ResourceManager.toAbsoluteFilePath(modelFolderUri);
		return getConfigurationManagerForIDE(modelFolderPath, ConfigurationManager.RDF_XML_ABBREV_FORMAT);
	}

	/**
	 * Initializes the backing ontology model for the EMF resource.
	 */
	protected def initOntModel(String content) {
		val ontModel = ModelFactory.createOntologyModel(OntModelSpec.OWL_MEM);
		ontModel.documentManager.processImports = false;
		ontModel.read(new StringInputStream(content), URI.toString, serializationLanguage);
		return ontModel;
	}

	/**
	 * Returns with the public URI (from the configuration manager) for the URI of the current EMF resource.
	 */
	protected def getBaseUri(ConfigurationManagerForIDE configurationManager) {
		val absoluteFilePath = ResourceManager.toAbsoluteFilePath(URI);
		val fileUrl = configurationManager.fileNameToFileUrl(absoluteFilePath);
		return configurationManager.getPublicUriFromActualUrl(fileUrl);
	}

	private def getBaseUri(OntModel model, String content) {
		val baseUri = model.getNsPrefixURI('');
		if (baseUri === null) {
			val fileExtension = fileExtension;
			return if (fileExtension == 'n3' || fileExtension == 'nt') {
				model.listOntologies.head?.URI
			} else {
				new XMLHelper().tryReadBaseUri(content).orNull
			}
		}
		return baseUri;
	}

	/**
	 * Returns with the alternative base URI from the base URI. More precisely, if the base URI is not {@code null} 
	 * but ends with a trailing hash-mark ({@code #}) character returns with the base URI without the trailing 
	 * hash-mark. Otherwise, returns with the base URI. If the base URI is {@code null}, returns with {@code null};
	 */
	private def getAltBaseUri(String baseUri) {
		if (baseUri === null) {
			return null;
		}
		return if(baseUri.endsWith('#')) baseUri.substring(0, baseUri.length - 1) else baseUri;
	}
	
	/**
	 * The file extension of the current resource without the leading dot.
	 * For instance, {@code owl}, {@code n3} but not {@code .nt}.
	 */
	private def fileExtension() {
		return this.URI.fileExtension;
	}

	private def getOrCreateSadlModel(String baseUri) {
		var model = modelMapping.get(baseUri);
		if (model === null) {
			model = SADLFactory.eINSTANCE.createSadlModel => [
				it.baseUri = baseUri;
			];
			modelMapping.put(baseUri, model);
			this.getContents.add(model);
		}
		return model;
	}

	// TODO: do we really need to check its existence via the resource set?
	private def getModelFolderUri(URI resourceUri, Map<?, ?> options) {
		var segmentCount = resourceUri.segmentCount;
		for (var segmentsToDrop = 1; segmentsToDrop < segmentCount; segmentsToDrop++) {
			val shortenedUri = resourceUri.trimSegments(segmentsToDrop);
			val proposedModelFolderUri = shortenedUri.appendSegment(ResourceManager.OWLDIR);
			if (resourceSet.URIConverter.exists(proposedModelFolderUri, options)) {
				return getResourceSet.URIConverter.normalize(proposedModelFolderUri);
			}
		}
		return null;
	}

	private def createSadlResource(Resource rdfResource) {
		return SADLFactory.eINSTANCE.createSadlResource => [
			val conceptName = rdfResource.localName;
			val conceptUri = rdfResource.URI;
			val conceptType = rdfResource.ontConceptType;
			new ExternalResourceAdapter(conceptName, conceptUri, conceptType).attachToEmfObject(it);
			name = it;
		];
	}

	private def createSadlImport(EObject context, OntResource ontResource) {
		val ontResourceUri = ontResource.URI;
		return new LazyResolvedSadlImport(scopeProvider, ontResourceUri.alias, ontResourceUri);
	}
	
	private def getScopeProvider() {
		return injector.getInstance(IScopeProvider);
	}

	private def getAlias(String ontResourceUri) {
		var prefix = ontModel.getNsURIPrefix(ontResourceUri);
		if (prefix === null) {
			return ontModel.getNsURIPrefix('''«ontResourceUri»#''');
		}
		return prefix;
	}

	// TODO: duplicate of com.ge.research.sadl.builder.ConfigurationManagerForIDE.getOwlFormatFromFile(String)
	private def getSerializationLanguage() {
		return switch URI.fileExtension {
			case 'owl': 'RDF/XML'
			case 'nt': 'N-TRIPLE'
			case 'turtle': 'TURTLE'
			case 'n3': 'N3'
			default: 'RDF/XML'
		};
	}

	// TODO this does not belong to here. Should go to a utility class.
	private def getOntConceptType(Resource r) {
		var ctype = OntConceptType.CLASS
		if (r !== null) {
			if (r instanceof Individual) {
				ctype = OntConceptType.INSTANCE
			} else if (r.canAs(DatatypeProperty)) {
				ctype = OntConceptType.DATATYPE_PROPERTY
			} else if (r.canAs(ObjectProperty)) {
				ctype = OntConceptType.CLASS_PROPERTY
			} else if (r.canAs(OntClass)) {
				ctype = OntConceptType.CLASS
				var ExtendedIterator<Resource> itr = r.^as(OntClass).listRDFTypes(true)
				while (itr.hasNext()) {
					if (itr.next().equals(RDFS.Datatype)) {
						ctype = OntConceptType.DATATYPE
					}
				}
			} else if (r.canAs(AnnotationProperty)) {
				ctype = OntConceptType.ANNOTATION_PROPERTY
			} else if (r.canAs(Individual)) {
				ctype = OntConceptType.INSTANCE
			} else if (r.canAs(Property)) {
				ctype = OntConceptType.RDF_PROPERTY
			} else if (r.getNameSpace().equals(OWL.NAMESPACE.getNameSpace()) ||
				r.getNameSpace().equals(RDFS.getURI())) {
				// this is an OWL or RDFS concept--requires special handling
				if (r.equals(RDFS.comment) || r.equals(RDFS.label) || r.equals(RDFS.seeAlso)) {
					ctype = OntConceptType.ANNOTATION_PROPERTY
				} else if (Character.isLowerCase(r.getLocalName().charAt(0))) {
					ctype = OntConceptType.CLASS_PROPERTY
				} else {
					ctype = OntConceptType.CLASS
				} // if (r.equals(OWL.allValuesFrom) || r.equals(OWL.))
			} else if (r.equals(RDFS.subClassOf)) {
				ctype = OntConceptType.CLASS_PROPERTY
			} else // TODO this doesn't work because of trying to actually get as OntCLass.
			// else if (r.equals(RDF.Property)) {
			// ctype = OntConceptType.ONTCLASS;
			// }
			if (r.canAs(Individual)) {
				ctype = OntConceptType.INSTANCE
			} else if (r.equals(RDF.type)) {
				ctype = OntConceptType.CLASS_PROPERTY
			}
		}
		return ctype

	}

}

class ExternalEmfResourceFactory extends ResourceFactoryImpl {

	public static val Collection<String> EXTERNAL_EXTENSIONS = #{'owl', 'nt', 'n3'};

	@Inject
	Injector injector;

	override createResource(URI uri) {
		return new ExternalEmfResource() => [
			it.URI = uri; 
			it.injector = injector;
		];
	}

}

@Data
@EmfAdaptable
class ExternalResourceAdapter {

	String concreteName;
	String conceptUri;
	OntConceptType type;

}

class ExternalEmfResourceServiceProvider implements IResourceServiceProvider {

	@Delegate
	@Inject
	IResourceServiceProvider delegate

	@Inject
	Injector injector;

	override canHandle(URI uri) {
		val name = uri.lastSegment;
		// exclude all generated OWL resources that has the corresponding SADL origin.
		// TODO add filter (GH-201). Metrics file should remain as is.
		if (name.endsWith("SadlBaseModel.owl") || name.endsWith("SadlListModel.owl") ||
			name.endsWith("SadlImplicitModel.owl") || name.endsWith("SadlBuiltinFunctions.owl")
			|| name.endsWith("metrics.owl")) {
			return false;
		}
		return ExternalEmfResourceFactory.EXTERNAL_EXTENSIONS.contains(uri.fileExtension);
	}

	override getResourceValidator() {
		return IResourceValidator.NULL;
	}

	override <T> get(Class<T> clazz) {
		if (GeneratorDelegate === clazz) {
			return injector.getInstance(ExternalEmfResourceGenerator) as T;
		}
		return delegate.get(clazz);
	}

}