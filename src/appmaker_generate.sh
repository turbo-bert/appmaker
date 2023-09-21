#!/bin/bash



funky_docker_scripts() {
    funky_dir=$1
    funky_tag=$2

    echo -en "#!/bin/bash\n\n\ndocker build -t $funky_tag .\n"                  >$funky_dir/DOCKER_BUILD.sh
    echo -en "#!/bin/bash\n\n\ndocker build --no-cache -t $funky_tag .\n"       >$funky_dir/DOCKER_BUILD_NOCACHE.sh
    echo -en "#!/bin/bash\n\n\ndocker run --rm -v \$PWD:/work -it $funky_tag\n" >$funky_dir/DOCKER_RUN.sh
    echo -en "#!/bin/bash\n\n\ndocker push $funky_tag\n"                        >$funky_dir/DOCKER_PUSH.sh

    echo -en "#!/bin/bash\n\n\ndocker buildx build --platform linux/arm64,linux/amd64 -t $funky_tag .\n"             >$funky_dir/X_DOCKER_BUILD_ALL.sh
    echo -en "#!/bin/bash\n\n\ndocker buildx build --platform linux/arm64,linux/amd64 --no-cache -t $funky_tag .\n"  >$funky_dir/X_DOCKER_BUILD_NOCACHE.sh
    echo -en "#!/bin/bash\n\n\ndocker buildx build --platform linux/arm64,linux/amd64 --push -t $funky_tag .\n"      >$funky_dir/X_DOCKER_PUSH.sh
    echo -en "#!/bin/bash\n\n\ndocker buildx build --load -t $funky_tag .\n"      >$funky_dir/X_DOCKER_BUILD_HERE.sh

    ( cd $funky_dir && chmod a+x *.sh )

}



if [[ ! -f appmaker.env ]]; then
    echo "There is no appmaker.env - do you want me to create a template?"
    echo "  empty = abort"
    echo "  py    = a typical python cli"
    read CH
    if [[ $CH = py ]]; then
        cat >appmaker.env <<EOF
DOCKER_ACCOUNT=YOUR_DOCKER_ACCOUNT
DOCKER_APP_NAME=test
DOCKER_APP_TYPE=py
DOCKER_APT_PKGS="openssl mc emacs-nox less dialog"
DOCKER_PIP_PKGS="reportlab flask requests"
EOF
    echo "I created appmaker.env with following content:"
    echo "###############################################"
    cat appmaker.env
    echo "###############################################"
    fi
    exit 0
fi



. appmaker.env


D="$DOCKER_ACCOUNT/$DOCKER_APP_NAME"
T="$D"

if [[ ! $1 = "-f" ]]; then
    echo     "Generate app from [appmaker.env]? (run with '-f' to suppress confirmation)"
    echo -en "Press RETURN to continue or CTRL-C to abort..."
    read
else
    rm -fr $D
fi

mkdir -p "$D"

############################################################################################
############################################################################################
############################################################################################
############################################################################################


if [[ $DOCKER_APP_TYPE = py ]]; then

    funky_docker_scripts $D $T


    #echo -en "#!/bin/bash\n\n\ndocker build -t $T .\n"             >$D/DOCKER_BUILD.sh
    #echo -en "#!/bin/bash\n\n\ndocker build --no-cache -t $T .\n"  >$D/DOCKER_BUILD_NOCACHE.sh
    #echo -en "#!/bin/bash\n\n\ndocker run -v \$PWD:/work -it $T\n" >$D/DOCKER_RUN.sh
    #echo -en "#!/bin/bash\n\n\ndocker push $T\n"                   >$D/DOCKER_PUSH.sh
#
#    #echo -en "#!/bin/bash\n\n\ndocker buildx build --platform linux/arm64,linux/amd64 -t $T .\n"             >$D/X_DOCKER_BUILD.sh
#    #echo -en "#!/bin/bash\n\n\ndocker buildx build --platform linux/arm64,linux/amd64 --no-cache -t $T .\n"  >$D/X_DOCKER_BUILD_NOCACHE.sh
#    #echo -en "#!/bin/bash\n\n\ndocker buildx build --platform linux/arm64,linux/amd64 --push -t $T .\n"      >$D/X_DOCKER_PUSH.sh
#    #echo -en "#!/bin/bash\n\n\ndocker buildx build --load -t $T .\n"      >$D/X_DOCKER_BUILD_NATIVE.sh
#
    #( cd $D && chmod a+x *.sh )

    mkdir -p $D/src/$DOCKER_APP_NAME

    mkdir -p $D/bin
    cat >$D/bin/$DOCKER_APP_NAME <<EOF
#!/bin/bash

docker run -it --rm -v \$PWD:/work $T
EOF

    chmod a+x $D/bin/$DOCKER_APP_NAME
    
    rsync -a src/$DOCKER_APP_NAME $D/src

#    cat >$D/src/$DOCKER_APP_NAME/__main__.py <<EOF
#print("stub - press RETURN")
#input()
#EOF
#    cat >$D/src/$DOCKER_APP_NAME/__init__.py <<EOF
#EOF
#
    cat >$D/Dockerfile <<EOF
FROM python:3

RUN apt update && apt upgrade -y

WORKDIR /app

RUN apt install -y mc $DOCKER_APT_PKGS

RUN pip3 install $DOCKER_PIP_PKGS

COPY src/$DOCKER_APP_NAME/. /app/$DOCKER_APP_NAME

CMD [ "python", "-u", "-m", "$DOCKER_APP_NAME" ]

EOF
fi

############################################################################################
############################################################################################
############################################################################################
############################################################################################

# php apache mysql...
if [[ $DOCKER_APP_TYPE = php ]]; then

    cat >$D/Dockerfile <<EOF
FROM php:8-apache

RUN apt update && apt upgrade -y

RUN apt install -y mc $DOCKER_APT_PKGS

RUN docker-php-ext-install $DOCKER_PHP_EXT

EOF

    mkdir -p $D/bin
    cat >$D/bin/$DOCKER_APP_NAME <<EOF
#!/bin/bash

docker run -it --rm -p 8080:80 -v \$PWD:/var/www/html $T
EOF
    chmod a+x $D/bin/$DOCKER_APP_NAME

    cat >$D/bin/$DOCKER_APP_NAME.linux <<EOF
#!/bin/bash

docker run -it --rm -p 8080:80 -v \$PWD:/var/www/html --add-host=host.docker.internal:host-gateway $T
EOF
    chmod a+x $D/bin/$DOCKER_APP_NAME.linux

    funky_docker_scripts $D $T

fi


############################################################################################
############################################################################################
############################################################################################
############################################################################################



#### docker buildx create --name mybuilder
#### docker buildx use mybuilder
#### docker buildx inspect --bootstrap
#### https://www.docker.com/blog/multi-arch-images/
