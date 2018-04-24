# Makefile

RESOURCES = \
	$(wildcard */*.js) \
	$(wildcard Styles/*.css) \
	ClientInline.html
	
SWIFT_RESOURCE_FILE = ClientResources.swift

all : $(SWIFT_RESOURCE_FILE)

clean :
	rm -f $(SWIFT_RESOURCE_FILE)

distclean : clean

$(SWIFT_RESOURCE_FILE) : $(RESOURCES)
	rm -f $@
	for RESOURCE_FILE in $(RESOURCES); do \
		nicename=$$(basename "$${RESOURCE_FILE}" | sed 's/\./_/g'); \
		echo "// Generated from $${RESOURCE_FILE}"	>> $@; \
		echo "//   on $$(date)" 			>> $@; \
		echo "//" 					>> $@; \
		echo "let rsrc_$${nicename} =" 			>> $@; \
		echo '"""' 					>> $@; \
		cat "$${RESOURCE_FILE}" 			>> $@; \
		echo '"""' 					>> $@; \
	done

