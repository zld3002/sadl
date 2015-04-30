/*
* generated by Xtext
*/
package com.ge.research.sadl.validation;

import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URISyntaxException;

import org.eclipse.core.runtime.CoreException;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtext.naming.IQualifiedNameProvider;
import org.eclipse.xtext.naming.QualifiedName;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.scoping.IGlobalScopeProvider;
import org.eclipse.xtext.scoping.IScope;
import org.eclipse.xtext.validation.Check;
import org.eclipse.xtext.validation.CheckType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ge.research.sadl.builder.IConfigurationManagerForIDE;
import com.ge.research.sadl.builder.ResourceManager;
import com.ge.research.sadl.builder.SadlModelManager;
import com.ge.research.sadl.builder.SadlModelManagerProvider;
import com.ge.research.sadl.model.PendingModelError;
import com.ge.research.sadl.reasoner.ConfigurationException;
import com.ge.research.sadl.reasoner.IConfigurationManager;
import com.ge.research.sadl.sadl.Import;
import com.ge.research.sadl.sadl.ModelName;
import com.ge.research.sadl.sadl.ResourceByName;
import com.ge.research.sadl.sadl.ResourceIdentifier;
import com.ge.research.sadl.sadl.ResourceName;
import com.ge.research.sadl.sadl.SadlPackage;
import com.ge.research.sadl.utils.SadlUtils;
import com.ge.research.sadl.utils.SadlUtils.ConceptType;
import com.google.inject.Inject;

/**
 * Custom validation rules. 
 *
 * see http://www.eclipse.org/Xtext/documentation.html#validation
 */
public class SadlJavaValidator extends com.ge.research.sadl.validation.AbstractSadlJavaValidator {
	public static final String MISSING_MODEL_NAME = "com.ge.research.SADL.MissingModelName";
	public static final String MISSING_HTTP_PREFIX = "com.ge.research.SADL.MissingHttpPrefix";
	public static final String DUPLICATE_MODEL_NAME = "com.ge.research.SADL.DuplicateModelName";
	public static final String IMPROPER_IMPORT_FILE_URI = "com.ge.research.SADL.ImproperImportFileUri";
	public static final String ADD_URI_END_CHAR = "com.ge.research.SADL.AddUriEndChar";
	public static final String ADD_MODEL_VERSION = "com.ge.research.SADL.AddModelVersion";
	public static final String ADD_GLOBAL_ALIAS = "com.ge.research.SADL.AddModelGlobalAlias";
	public static final String ONTCLASS_NOT_DEFINED = "com.ge.research.SADL.OntClassNotDefined";
	public static final String OBJECTPROPERTY_NOT_DEFINED = "com.ge.research.SADL.ObjectPropertyNotDefined";
	public static final String DATATYPEPROPERTY_NOT_DEFINED = "com.ge.research.SADL.DatatypePropertyNotDefined";
	public static final String INSTANCE_NOT_DEFINED = "com.ge.research.SADL.InstanceNotDefined";
	public static final String MISSING_ALIAS = "com.ge.research.SADL.MissingAlias";
	public static final String DOUBLE_ALIAS = "com.ge.research.SADL.DoubleAlias";
    
    private static final Logger logger = LoggerFactory.getLogger(SadlJavaValidator.class);
    
    @Inject
	private SadlModelManagerProvider sadlModelManagerProvider;
    
    @Inject
    private IGlobalScopeProvider globalScopeProvider;
    @Inject
    private IQualifiedNameProvider qnProvider;
    
    /**
     * Through (transitive) imports the short name ResourceName referred by a ResourceNyName might
     * be multiple times on the scope, but only the first one is linked. There should be a warning that
     * this is ambiguous.
     * @param rn
     */
    @Check(CheckType.NORMAL)
    public void checkNoAmbiguousQualifiedNameOnScope (ResourceByName rn) {
    	if (rn.eResource()==null || rn.getName().eIsProxy()) return;
    	// the qualified name of the actually linked ResourceName
    	QualifiedName qn = qnProvider.getFullyQualifiedName(rn.getName());
    	// search the global scope for any other name
    	IScope scope = globalScopeProvider.getScope(rn.eResource(), SadlPackage.Literals.RESOURCE_BY_NAME__NAME, null);
    	for (IEObjectDescription description : scope.getAllElements()) {
			if (qn.getLastSegment().equals(description.getQualifiedName()) && !qn.equals(description.getQualifiedName())) {
				warning("The name "+qn.getLastSegment()+" is ambiguous. Please qualify the name", rn, SadlPackage.Literals.RESOURCE_BY_NAME__NAME);
				return;
			}
		}
    }
	
	@Check
	public void checkModelName(ModelName uri) {
	    // Most of our checks will focus on the baseUri feature.
	    String baseUri = uri.getBaseUri();

		if (baseUri == null || baseUri.isEmpty()) {
			error("Model name cannot be empty", uri, SadlPackage.Literals.MODEL_NAME__BASE_URI, MISSING_MODEL_NAME);			
		}
		else if (!baseUri.startsWith(IConfigurationManager.HTTP_URL_PREFIX)) {
			error("Model name must be a valid URI", SadlPackage.Literals.MODEL_NAME__BASE_URI, MISSING_HTTP_PREFIX, baseUri);
		}
		else {
			try {
				baseUri = ResourceManager.validateHTTP_URI(baseUri);
			}
			catch (Exception e) {
		        error(e.getLocalizedMessage(), SadlPackage.Literals.MODEL_NAME__BASE_URI);
				
			}
	        try {
	            URI modelUrl = uri.eResource().getURI();
                String owlUrl = ResourceManager.validateAndReturnOwlUrlOfSadlUri(modelUrl).toString();
		        String publicUri = baseUri;
		        SadlModelManager visitor = sadlModelManagerProvider.get(modelUrl);
		        String altUri = visitor.getAltUrl(publicUri, modelUrl);
		        // If those urls differ, that indicates another model has already used the public uri
		        if (altUri != null && !publicUri.equals(altUri) && !owlUrl.equals(altUri)) {
		            error("Model name must be unique", SadlPackage.Literals.MODEL_NAME__BASE_URI, DUPLICATE_MODEL_NAME, baseUri);
		        }
            }
	        catch (CoreException e) {
                e.printStackTrace();
			} catch (MalformedURLException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}

		if (uri.getVersion() == null) {
			warning("No model version present", uri, SadlPackage.Literals.MODEL_NAME__VERSION, ADD_MODEL_VERSION);
		}
		if (uri.getAlias() == null) {
			warning("Model does not have a global alias", uri, SadlPackage.Literals.MODEL_NAME__ALIAS, ADD_GLOBAL_ALIAS);
		}
	}
	
    @Check
    public void checkImport(Import imp) {
    	String uri = imp.getImportURI();
		if (uri.startsWith(ResourceManager.FILE_URL_PREFIX)) {
			warning("File-type URL is improper; hyperlinking may not work.", imp, SadlPackage.Literals.IMPORT__IMPORT_URI, IMPROPER_IMPORT_FILE_URI);
		}
		// do we have a global alias?
		try {
			SadlModelManager visitor = sadlModelManagerProvider.get(imp.eResource().getURI());
			String modelFolder = ResourceManager.getProjectUri(imp.eResource().getURI()).appendSegment(ResourceManager.OWLDIR).toString();
    		IConfigurationManagerForIDE configMgr = visitor.getConfigurationMgr(modelFolder);
    		if (!configMgr.containsMappingForURI(uri)) {
    			configMgr = ResourceManager.findConfigurationManagerInOtherProject(sadlModelManagerProvider, 
    					ResourceManager.getProjectUri(imp.eResource().getURI()).appendSegment(ResourceManager.OWLDIR), uri);
    		}
    		if (configMgr != null) {
    			if (uri.endsWith(ResourceManager.SADLEXTWITHPREFIX)) {
    				if (uri.startsWith(ResourceManager.FILE_URL_PREFIX)) {
		    			int idx = ResourceManager.FILE_URL_PREFIX.length();
		    			while (idx < uri.length() && uri.charAt(idx) == '/') {
		    				idx++;
		    			}
		    			uri = uri.substring(idx);
    				}
    				
					URI projectUri = ResourceManager.getProjectUri(visitor.getModelResource().getURI());
					SadlUtils su = new SadlUtils();
					URI sadlUri = URI.createURI(su.fileNameToFileUrl(ResourceManager.findSadlFileInProject(projectUri.toFileString(), uri)));
					URI owlUri = ResourceManager.validateAndReturnOwlUrlOfSadlUri(sadlUri);
					uri = configMgr.findPublicUriOfOwlFile(owlUri.toString());
	    		}
    			String globalAlias = configMgr.getGlobalPrefix(uri);
    			if (globalAlias == null && imp.getAlias() == null) {
	    			warning("An imported model without a global alias may need a local alias.", imp, SadlPackage.Literals.IMPORT__ALIAS, MISSING_ALIAS);			        			
	    		}
	    		else if (globalAlias != null && imp.getAlias() != null) {
	    			warning("Giving a local alias to an imported model with a global alias may be confusing.", imp, SadlPackage.Literals.IMPORT__ALIAS, DOUBLE_ALIAS);			        				    			
	    		}
    		}
		} catch (ConfigurationException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (CoreException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (URISyntaxException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (MalformedURLException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
    	if (imp.getAlias() == null) {
		}
    }
    
	@Check
	public void checkResourceIdentifier(ResourceIdentifier rsrcId) {
		if (rsrcId instanceof ResourceByName) {
			ResourceName name = ((ResourceByName)rsrcId).getName();
			if (name != null) {
				String nm = name.getName();
				if (nm == null) {
					logger.debug("Unresolved name doesn't allow a quick fix to be identified.");
				}
//				if (visitor.getModelBaseUri() == null) {
//					// the model hasn't been parsed so we can't generate quick fixes until we parse it
//					visitor.processModel(rsrcId.resource, false, null)
//				}
				Resource resource = rsrcId.eResource();
				PendingModelError pendingErr = null;
				SadlModelManager visitor = sadlModelManagerProvider.get(resource.getURI());
				if (visitor.hasModelManager(resource)) { 
					pendingErr = visitor.getPendingError(resource, nm);
				}
				if (pendingErr != null) {
					if (pendingErr.getConceptType().equals(ConceptType.ONTCLASS)) {
						error("Class not found", rsrcId, SadlPackage.Literals.RESOURCE_BY_NAME__NAME, ONTCLASS_NOT_DEFINED);
					}
					else if (pendingErr.getConceptType().equals(ConceptType.OBJECTPROPERTY)) {
						error("Object property not found", rsrcId, SadlPackage.Literals.RESOURCE_BY_NAME__NAME, OBJECTPROPERTY_NOT_DEFINED);
					}
					else if (pendingErr.getConceptType().equals(ConceptType.DATATYPEPROPERTY)) {
						error("Data property not found", rsrcId, SadlPackage.Literals.RESOURCE_BY_NAME__NAME, DATATYPEPROPERTY_NOT_DEFINED);	
					}
					else if (pendingErr.getConceptType().equals(ConceptType.INDIVIDUAL)) {
						error("Instance not found", rsrcId, SadlPackage.Literals.RESOURCE_BY_NAME__NAME, INSTANCE_NOT_DEFINED);	
					}
				}
			}
		}
	}
}
