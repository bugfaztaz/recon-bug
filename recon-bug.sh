#!/bin/bash

# Parsear argumentos
while getopts ":u:b:" opt; do
  case ${opt} in
    u )
      url=${OPTARG}
        TARGET_FOLDER=$(basename $url)
      if [ ! -d "targets/$TARGET_FOLDER" ]; then
        mkdir -p "targets/$TARGET_FOLDER"
      fi
      # Cambiar al directorio targets
      cd targets/$TARGET_FOLDER || { echo "No se pudo cambiar al directorio targets"; exit 1; }
      # Escanear subdominios
      subdomains=$(assetfinder --subs-only "$url")

      # Verificar que se encontraron subdominios
      if [[ -z $subdomains ]]; then
        echo "No se encontraron subdominios para la URL $url" 1>&2
        exit 1
      fi

      # Nombre del archivo de salida
      output_file="assetfinder-$(echo $url | cut -d'/' -f3).txt"

      # Guardar los resultados en el archivo de salida
      echo "$subdomains" > "$output_file"

      # Mostrar un mensaje de éxito
      echo "Los subdominios encontrados se guardaron en el archivo $output_file en la carpeta targets/$TARGET_FOLDER"
      

      
      echo "Escaneando con amass" 
      # Escanear subdominios
      amass=$(amass enum -d "$url" )     

      # Verificar que se encontraron subdominios
      if [[ -z $amass ]]; then
        echo "No se encontraron subdominios para la URL con amass $url" 1>&2
        exit 1
      fi

      # Nombre del archivo de salida
      output_file_amass="amass-$(echo $url | cut -d'/' -f3).txt"

      # Guardar los resultados en el archivo de salida
      echo "$amass" > "$output_file_amass"

      # Mostrar un mensaje de éxito
      echo "Los subdominios encontrados con amass se guardaron en el archivo $output_file_amass en la carpeta targets/$TARGET_FOLDER"

       # Juntar los archivos de subdominios$url
      cat assetfinder*.txt amass*.txt > all-subdomains.txt
      echo "Se han juntado los archivos de subdominios generados por assetfinder y amass en un solo archivo all-subdomains.txt en la carpeta targets/$TARGET_FOLDER"
      echo "extraer los dominios y quitar todos los demas datos"
      cat all-subdomains.txt | grep -oP '\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\b' | tee -a all-subz.txt    
      echo "eliminar duplicados"
      cat all-subz.txt | sort  | uniq  > all-subdomains-list.txt
    
      echo "pasar output.txt por httprobe"
      cat all-subdomains-list.txt | httprobe | tee -a output-live.txt
      echo "eliminar http: urls from output-live.txt"
      sed -i '/^http:\/\//d' output-live.txt
      echo "eliminar duplicados"
      cat output-live.txt | sort | uniq > all-output-list.txt 
      echo "juntar todos los archivos de subdominios"
      cat all-output-list.txt > all-subs.txt
      echo "eliminar subdominios HTTP"
      cat all-subs.txt|grep -E '^https://' | sed 's/http:\/\///' > subs_https.txt 
      echo "con waybackurls obtenemos todos los endpoints"
      cat subs_https.txt | waybackurls | tee -a endpoint.txt 
      echo " obtener los codigos http y las tecnologias"
      cat endpoint.txt | httpx -title -tech-detect -status-code | tee -a enpoint-status-code.txt   
      echo "extraer url parametros SSRF con grep"
      cat endpoint.txt | grep "?next=" | tee -a grep_next.txt
      cat endpoint.txt | grep "?host=" | tee -a grep_host.txt
      cat endpoint.txt | grep "?continue=" | tee -a grep_continue.txt
      cat endpoint.txt | grep "?img-src=" | tee -a grep_img-src.txt
      cat endpoint.txt | grep "?u=" | tee -a grep_u.txt
      cat endpoint.txt | grep "?url=" | tee -a grep_url.txt
      cat endpoint.txt | grep "?to=" | tee -a grep_to.txt
      js_files=$(katana -u "$url" -jc -d 2 | grep ".js$" | uniq | sort)
      echo "$js_files" > js.txt
      ;;
    b )
      backup_url=${OPTARG}
      ;;
    \? )
      echo "Opción inválida: -$OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Opción -$OPTARG requiere un argumento" 1>&2
      exit 1
      ;;
  esac
done

# Ejecutar la lógica asociada a la opción -b si backup_url está definida
if [ -n "$backup_url" ]; then
    echo "La URL opcional introducida es: $backup_url"
    # Verificar si se ha establecido el directorio del target
    # Usar backup_url con qsreplace para crear ssrf.txt en la carpeta del target
    cat endpoint.txt | grep "=" | qsreplace "$backup_url" > ssrf.txt
    echo "Se ha creado el archivo ssrf.txt con las URLs modificadas en targets/$TARGET_FOLDER."
    cat ssrf.txt | httpx -fr 
fi






